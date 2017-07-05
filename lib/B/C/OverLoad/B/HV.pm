package B::C::HV;

my $hv_index = 0;

sub get_index {
    return $hv_index;
}

sub inc_index {
    return ++$hv_index;
}

1;

package B::HV;

use strict;
require mro;

use B qw/cstring SVf_READONLY SVf_PROTECT SVs_OBJECT SVf_OOK SVf_AMAGIC/;
use B::C::Config;
use B::C::File qw/init xpvhvsect svsect sharedhe decl init init2 init_stash init_static_assignments/;
use B::C::Helpers qw/read_utf8_string strlen_flags/;
use B::C::Helpers::Symtable qw/objsym savesym/;
use B::C::Save::Hek qw/save_shared_he get_sHe_HEK/;
use B::C::Save qw/savestashpv/;

my ($swash_ToCf);

sub swash_ToCf_value {    # NO idea what it s ??
    return $swash_ToCf;
}

sub can_save_stash {
    my $stash_name = shift;

    #return get_current_stash_position_in_starting_stash ( $stash_name ) ? 1 : 0;

    return 1 if $stash_name eq 'main';

    $stash_name =~ s{::$}{};
    $stash_name =~ s{^main::}{};

    # ... do something with names containing a pad FIXME ( new behavior good to have )

    my $starting_flat_stashes = $B::C::settings->{'starting_flat_stashes'} or die;
    return $starting_flat_stashes->{$stash_name} ? 1 : 0;    # need to skip properly ( maybe just a protection there
}

sub key_was_missing_from_stash_at_compile {
    my ( $stash_name, $key, $curstash ) = @_;

    ### STATIC_HV need improvement there - using a more generic method for whitelisting
    if ( !$stash_name && $key && $key =~ qr{^B::C::} ) {
        return 1;
    }

    # when it s not a stash (noname) we always want to save all the keys from the hash
    return 0 unless $stash_name;

    # if do not have a pointer to a stash in starting_stash, we should not save the key
    return 1 if ref $curstash ne 'HASH';

    # no need to check if the stash name is in starting_stashes ( we know this for sure )

    # was the key defined at startup by starting_stash() ?
    return !$curstash->{$key};
}

# our only goal here is to get the curstash position in starting_stash if it exists
sub get_current_stash_position_in_starting_stash {
    my ($stash_name) = @_;

    return unless $stash_name;    # <---- we want to save all *keys*

    $stash_name =~ s{::$}{};
    $stash_name =~ s{^main::}{};

    my $curstash = $B::C::settings->{'starting_stash'};

    if ( $stash_name ne 'main' ) {
        foreach my $sect ( split( '::', $stash_name ) ) {
            $curstash = $curstash->{ $sect . '::' } or return;    # Should never happen.
            ref $curstash eq 'HASH' or return;
        }
    }

    return $curstash;
}

sub do_save {
    my ( $hv, $fullname ) = @_;

    $fullname ||= '';
    my $stash_name = $hv->NAME;

    #debug( hv => "XXXX HV fullname %s // name %s", $fullname, $stash_name );
    if ($stash_name) {

        $stash_name =~ s/^main::(.+)$/$1/;    # Strip off main:: on everything but main::

        if ( !can_save_stash($stash_name) ) {
            debug( hv => 'skipping stash ' . $stash_name );
            return q{NULL};
        }
        debug( hv => 'Saving stash ' . $stash_name );
    }

    # protect against recursive self-reference
    # i.e. with use Moose at stash Class::MOP::Class::Immutable::Trait
    # value => rv => cv => ... => rv => same hash

    my $sv_list_index = svsect()->add("FAKE_HV");
    my $sym = savesym( $hv, "(HV*)&sv_list[$sv_list_index]" );

    # could also simply use: savesym( $hv, sprintf( "s\\_%x", $$hv ) );

    my $cache_stash_entry;

    my $current_stash_position_in_starting_stash = get_current_stash_position_in_starting_stash($stash_name);

    # reduce the content
    # remove values from contents we are not going to save
    my @hash_content_to_save;
    my @contents = $hv->ARRAY;

    if (@contents) {
        local $B::C::const_strings = $B::C::const_strings;
        my ( $i, $length );
        $length = scalar(@contents);

        # Walk the values and save them into symbols
        for ( $i = 1; $i < @contents; $i += 2 ) {
            my $key = $contents[ $i - 1 ];    # string only
            my $sv  = $contents[$i];
            my $value;

            if ( key_was_missing_from_stash_at_compile( $stash_name, $key, $current_stash_position_in_starting_stash ) ) {
                debug( hv => '...... Skipping key "%s" from stash "%s" (missing) ', $key, $stash_name );
                next;
            }

            if ( debug('hv') and ref($sv) eq 'B::RV' and defined objsym($sv) ) {
                WARN( "HV recursion? with $fullname\{$key\} -> %s\n", $sv->RV );
            }

            debug( hv => "saving HV [ $i / len=$length ]\$" . $fullname . '{' . $key . "} 0x%0x", $sv );
            $value = $sv->save( $fullname . '{' . $key . '}' );    # Turn the hash value into a symbol
            next if $value eq q{NULL};                             # this can comes from ourself ( view above )

            push @hash_content_to_save, [ $key, $value ] if defined $value;
        }
    }

    # Ordinary HV or Stash
    # KEYS = 0, inc. dynamically below with hv_store

    my $hv_total_keys = scalar(@hash_content_to_save);
    my $max           = get_max_hash_from_keys($hv_total_keys);
    xpvhvsect()->comment("xmg_stash, xmg_u, xpv_cur, xpv_len_u, xhv_keys, xhv_max");
    xpvhvsect()->saddl(
        '%s'   => $hv->save_magic_stash,                                                           # xmg_stash
        '{%s}' => $hv->save_magic( length $stash_name ? '%' . $stash_name . '::' : $fullname ),    # mgu
        '%d'   => $hv_total_keys,                                                                  # xhv_keys
        '%d'   => $max                                                                             # xhv_max
    );

    my $flags = $hv->FLAGS & ~SVf_READONLY & ~SVf_PROTECT;

    # replace the previously saved svsect with some accurate content
    svsect()->update(
        $sv_list_index,
        sprintf(
            "&xpvhv_list[%d], %Lu, 0x%x, {0}",
            xpvhvsect()->index, $hv->REFCNT, $flags
        )
    );

    my $init = $stash_name ? init_stash() : init_static_assignments();

    my $has_ook = $flags & SVf_OOK ? q{TRUE} : q{FALSE};    # only need one AUX when OOK is set
    my $backrefs_sym = 0;
    if ( my $backrefs = $hv->BACKREFS ) {

        # backref is by default a list AV, but when only one single GV is in this list, then the AV is saved
        if ( ref $backrefs eq 'B::AV' ) {
            $backrefs_sym = $backrefs->save( undef, undef, 'backref_save' );
        }
        else {
            # backrefs is not an array - single element list - backrefs=GV
            if ( !B::AV::skip_backref_sv($backrefs) ) {
                $backrefs_sym = $backrefs->save();
            }
        }
    }

    {    # add hash content even if the hash is empty [ maybe only for %INC ??? ]
        $init->no_split;
        my $comment = $stash_name ? "/* STASH declaration for ${stash_name}:: */" : '';
        $init->sadd( '{ %s', $comment );
        $init->indent(+1);
        $init->add( B::C::Memory::HvSETUP( $sym, $max + 1, $has_ook, $backrefs_sym ) );

        my @hash_elements;
        {
            my $i = 0;
            my %hash_kv = ( map { $i++, $_ } @hash_content_to_save );
            @hash_elements = values %hash_kv;    # randomize the hash eleement order to the buckets [ when coliding ]
        }

        # uncomment for saving hashes in a consistent order while debugging
        #@hash_elements = @hash_content_to_save;

        foreach my $elt (@hash_elements) {
            my ( $key, $value ) = @$elt;

            # Insert each key into the hash.
            my ($shared_he) = save_shared_he($key);
            $init->sadd( q{HvAddEntry(%s, (SV*) %s, %s, %d); /* %s */}, $sym, $value, $shared_he, $max, $key );
        }

        # save the iterator in hv_aux (and malloc it)
        $init->sadd( "HvRITER_set(%s, %d);", $sym, -1 );    # saved $hv->RITER
    }

    $init->add("SvREADONLY_on($sym);") if $hv->FLAGS & SVf_READONLY;

    # Setup xhv_name_u and xhv_name_count in the AUX section of the hash via hv_name_set.
    my @enames     = $hv->ENAMES;
    my $name_count = $hv->name_count;
    warn("Found an example of a non-zero HvAUX name_count!") if $name_count;
    if ( scalar @enames and !length $enames[0] and $stash_name ) {
        warn("Found empty ENAMES[0] for $stash_name");
    }

    foreach my $hash_name (@enames) {
        next unless length $hash_name;
        my ($shared_he) = save_shared_he($hash_name);
        $init->sadd( q{HvAUX(%s)->xhv_name_u.xhvnameu_name = %s; /* %s */}, $sym, get_sHe_HEK($shared_he), $hash_name );
    }

    # Special stuff we want to do for stashes.
    if ( length $stash_name ) {

        # SVf_AMAGIC is set on almost every stash until it is
        # used.  This forces a transversal of the stash to remove
        # the flag if its not actually needed.
        # fix overload stringify
        # Gv_AMG: potentially removes the AMG flag
        if ( $hv->FLAGS & SVf_AMAGIC ) {    #and $hv->Gv_AMG
            my $do_mro_isa_changed = eval { $hv->Gv_AMG };
            $do_mro_isa_changed = 1 if $@;    # fallback - view xtestc/0184.t
            init2()->sadd( "mro_isa_changed_in(%s);  /* %s */", $sym, $stash_name ) if $do_mro_isa_changed;
        }
        my $get_mro = ( scalar %main::mro:: ) ? mro->can('get_mro') : 0;
        if ( $stash_name ne 'mro' and $get_mro and $get_mro->($stash_name) eq 'c3' ) {
            init2()->sadd( 'Perl_mro_set_mro(aTHX_ HvMROMETA(%s), newSVpvs("c3")); /* %s */', savestashpv($stash_name), $stash_name );
        }
    }

    # close our HvSETUP block
    $init->indent(-1);
    $init->add('}');
    $init->split;

    return $sym;
}

sub get_max_hash_from_keys {
    my ( $keys, $default ) = @_;
    $default ||= 7;

    return $default if !$keys or $keys <= $default;    # default hash max value

    return 2**( int( log($keys) / log(2) ) + 1 ) - 1;
}

1;
