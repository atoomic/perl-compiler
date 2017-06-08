package B::PADNAME;

# MyPADNAME

use strict;

use B qw/cstring/;
use B::C::File qw( padnamesect );
use B::C::Config;

our $MAX_PADNAME_LENGTH = 1;

sub do_save {
    my ( $pn, $fullname ) = @_;

    my $xpadn_ourstash = sprintf( "(HV*) %s", $pn->OURSTASH->save($fullname) );
    my $xpadn_type_u   = sprintf( "(HV*) %s", $pn->TYPE->save($fullname) );

    my $refcnt = $pn->REFCNT;
    $refcnt++ if $refcnt < 1000;    # XXX protect from free, but allow SvREFCOUNT_IMMORTAL

    my $pv = $pn->PVX;
    my $xpadn_str = cstring($pv) || '{0}';

    my $ix = padnamesect()->index + 1;
    my $sym = sprintf( "&padname_list[%d]", $ix );

    my $xpadn_pv = $ix ? sprintf( "((char*)%s)+STRUCT_OFFSET(struct padname_with_str, xpadn_str[0])", $sym ) : 'NULL';

    my $xpadn_refcnt = $refcnt >= 1000 ? sprintf( "0x%x", $refcnt ) : $refcnt + 1;

    # Track the largest padname length to determine the size of the struct.
    my $xpadn_len = $pn->LEN;
    $MAX_PADNAME_LENGTH = $xpadn_len if $xpadn_len > $MAX_PADNAME_LENGTH;

    # 5.22 needs the buffer to be at the end, and the pv pointing to it.
    # We allocate a static buffer, and for uniformity of the list pre-alloc.
    # We set it to the max length of the largest variable.
    padnamesect()->comment(" pv, ourstash, type_u, low, high, refcnt, gen, len, flags, str");

    # Provided in base.c.tt2 custom to deal with xpadn_str needing to be fixed in size.
    padnamesect()->saddl(
        "%s"   => $xpadn_pv,                  # char *xpadn_pv;
        "%s"   => $xpadn_ourstash,            # HV *xpadn_ourstash;
        "{%s}" => $xpadn_type_u,              # union { HV *xpadn_typestash; CV *xpadn_protocv; } xpadn_type_u;
        "%u"   => $pn->COP_SEQ_RANGE_LOW,     # U32 xpadn_low;
        "%u"   => $pn->COP_SEQ_RANGE_HIGH,    # U32 xpadn_high;
        "%s"   => $xpadn_refcnt,              # U32 xpadn_refcnt;
        "%i"   => $pn->GEN,                   # int xpadn_gen;
        "%u"   => $xpadn_len,                 # U8  xpadn_len;
        "0x%x" => $pn->FLAGS & 0xff,          # U8  xpadn_flags; /* U8 + FAKE if OUTER. OUTER,STATE,LVALUE,TYPED,OUR */
        "%s"   => $xpadn_str,                 # char xpadn_str[60]; /* longer lexical upval names are forbidden for now */
    );

    padnamesect()->debug( $fullname . " " . $pv, $pn->flagspv ) if debug('flags');

    return $sym;
}

1;
