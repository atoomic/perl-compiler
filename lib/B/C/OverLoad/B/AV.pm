package B::AV;

use strict;

use B::C::Flags ();

use B qw/cstring SVf_IOK SVf_POK SVs_OBJECT/;
use B::C::Config;
use B::C::File qw/init xpvavsect svsect init_static_assignments init_bootstraplink/;
use B::C::Helpers qw/strlen_flags/;
use B::C::Helpers::Symtable qw/savesym/;

# maybe need to move to setup/config
my ( $use_av_undef_speedup, $use_svpop_speedup ) = ( 1, 1 );
my $MYMALLOC = $B::C::Flags::Config{usemymalloc} eq 'define';

sub fill {
    my $av = shift;

    my $fill = eval { $av->FILL };    # cornercase: tied array without FETCHSIZE
    $fill = -1 if $@;                 # catch error in tie magic

    return $fill;
}

sub cast_sv {
    return "(SV*)";
}

sub save_sv {
    my ( $av, $fullname ) = @_;

    my $fill = $av->fill();           # could be using PADLIST, PADNAMELIST, or AV method for this.

    xpvavsect()->comment('xmg_stash, xmg_u, xav_fill, xav_max, xav_alloc');
    my $xpv_ix = xpvavsect()->saddl(
        "%s"   => $av->save_magic_stash,         # xmg_stash
        "{%s}" => $av->save_magic($fullname),    # xmg_u
        "0x%x" => $fill,                         # xav_fill
        "0x%x" => $fill,                         # xav_max
        "%s"   => "NULL",                        # xav_alloc  /* pointer to beginning of C array of SVs */ This has to be dynamically setup at init().
    );

    svsect()->sadd( "&xpvav_list[%d], %Lu, 0x%x, {%s}", $xpv_ix, $av->REFCNT + 1, $av->FLAGS, 0 );

    svsect()->debug( $fullname, $av );
    my $sv_ix    = svsect()->index;
    my $av_index = xpvavsect()->index;

    # protect against recursive self-references (Getopt::Long)
    return savesym( $av, "(AV*)&sv_list[$sv_ix]" );
}

sub do_save {
    my ( $av, $fullname, $cv ) = @_;

    $fullname ||= '';

    my $fill = $av->fill();

    my $sym = $av->save_sv($fullname);    # could be using PADLIST, PADNAMELIST, or AV method for this.

    debug( av => "saving AV %s 0x%x [%s] FILL=%d", $fullname, $$av, ref($av), $fill );

    # XXX AVf_REAL is wrong test: need to save comppadlist but not stack
    # STATIC HV: We used to block save on @- and @+ by checking for magic of type D. save_magic doesn't advertize this now so we don't have the "same" blocker.
    if ( $fill > -1 and $fullname !~ m/^(main::)?[-+]$/ ) {
        my @array = $av->ARRAY;    # crashes with D magic (Getopt::Long)
        if ( debug('av') ) {
            my $i = 0;
            foreach my $el (@array) {
                my $val = '';

                # if SvIOK print iv, POK pv
                if ( $el->can('FLAGS') ) {
                    $val = $el->IVX           if $el->FLAGS & SVf_IOK;
                    $val = cstring( $el->PV ) if $el->FLAGS & SVf_POK;
                }
                debug( av => "AV %s \[%d] = %s %s", $av, $i++, ref($el), $val );
            }
        }

        #	my @names = map($_->save, @array);
        # XXX Better ways to write loop?
        # Perhaps svp[0] = ...; svp[1] = ...; svp[2] = ...;
        # Perhaps I32 i = 0; svp[i++] = ...; svp[i++] = ...; svp[i++] = ...;

        # micro optimization: op/pat.t ( and other code probably )
        # has very large pads ( 20k/30k elements ) passing them to
        # ->add is a performance bottleneck: passing them as a
        # single string cuts runtime from 6min20sec to 40sec

        # you want to keep this out of the no_split/split
        # map("\t*svp++ = (SV*)$_;", @names),
        my $acc = '';

        # Init optimization by Nick Koston
        # The idea is to create loops so there is less C code. In the real world this seems
        # to reduce the memory usage ~ 3% and speed up startup time by about 8%.
        my ( $count, @values );
        {
            # TODO: This local may no longer be needed now we've removed the 5.16 conditional here.
            local $B::C::const_strings = $B::C::const_strings;

            @values = map { $_->save( $fullname . "[" . $count++ . "]" ) || () } @array;
        }

        $count = 0;
        my $svpcast = $av->cast_sv();    # could be using PADLIST, PADNAMELIST, or AV method for this.

        for ( my $i = 0; $i <= $#array; $i++ ) {
            if ( $fullname =~ m/^(INIT|END)$/ and $values[$i] and ref $array[$i] eq 'B::CV' ) {
                init()->sadd( 'SvREFCNT_inc(%s); /* bump $fullname */', $values[$i] );
            }
            if (   $use_svpop_speedup
                && defined $values[$i]
                && defined $values[ $i + 1 ]
                && defined $values[ $i + 2 ]
                && $values[$i] =~ /^\&sv_list\[(\d+)\]/
                && $values[ $i + 1 ] eq "&sv_list[" . ( $1 + 1 ) . "]"
                && $values[ $i + 2 ] eq "&sv_list[" . ( $1 + 2 ) . "]" ) {
                $count = 0;
                while ( defined( $values[ $i + $count + 1 ] ) and $values[ $i + $count + 1 ] eq "&sv_list[" . ( $1 + $count + 1 ) . "]" ) {
                    $count++;
                }
                $acc .= "\tfor (gcount=" . $1 . "; gcount<" . ( $1 + $count + 1 ) . "; gcount++) {" . " *svp++ = $svpcast&sv_list[gcount]; };\n\t";
                $i += $count;
            }
            elsif ($use_av_undef_speedup
                && defined $values[$i]
                && defined $values[ $i + 1 ]
                && defined $values[ $i + 2 ]
                && $values[$i] =~ /^ptr_undef|&PL_sv_undef$/
                && $values[ $i + 1 ] =~ /^ptr_undef|&PL_sv_undef$/
                && $values[ $i + 2 ] =~ /^ptr_undef|&PL_sv_undef$/ ) {
                $count = 0;
                while ( defined $values[ $i + $count + 1 ] and $values[ $i + $count + 1 ] =~ /^ptr_undef|&PL_sv_undef$/ ) {
                    $count++;
                }
                $acc .= "\tfor (gcount=0; gcount<" . ( $count + 1 ) . "; gcount++) {" . " *svp++ = $svpcast&PL_sv_undef; };\n\t";
                $i += $count;
            }
            else {    # XXX 5.8.9d Test::NoWarnings has empty values
                $acc .= "\t*svp++ = $svpcast" . ( $values[$i] ? $values[$i] : '&PL_sv_undef' ) . ";\n\t";
            }
        }

        $av->add_to_init( $sym, $acc, $fill, $fullname );

        # should really scan for \n, but that would slow
        # it down
        init()->inc_count($#array);
    }
    else {
        my $max = $av->MAX;
        init()->add("av_extend($sym, $max);") if $max > -1;
    }

    return $sym;
}

# With -fav-init faster initialize the array as the initial av_extend()
# is very expensive.
# The problem was calloc, not av_extend.
# Since we are always initializing every single element we don't need
# calloc, only malloc. wmemset'ting the pointer to PL_sv_undef
# might be faster also.

sub add_to_init {
    my ( $av, $sym, $acc, $fill, $fullname ) = @_;

    my $deferred_init = $acc =~ qr{BOOTSTRAP_XS_}m ? init_bootstraplink() : init_static_assignments();

    $deferred_init->no_split;
    $deferred_init->sadd( "{ /* Initialize array %s */", $fullname );
    $deferred_init->indent(+1);

    $deferred_init->add("register int gcount;") if $acc =~ m/\(gcount=/m;
    $av->add_malloc_line_for_array_init( $deferred_init, $sym, $fill );
    $deferred_init->add( substr( $acc, 0, -2 ) );    # AvFILLp already in XPVAV

    $deferred_init->indent(-1);
    $deferred_init->add("}");
    $deferred_init->split;
}

sub add_malloc_line_for_array_init {
    my ( $av, $deferred_init, $sym, $fill ) = @_;
    return if !defined $fill;

    $fill = $fill < 3 ? 3 : $fill + 1;

    $deferred_init->sadd( "SV **svp = INITAv(%s, %d);", $sym, $fill );
}

1;
