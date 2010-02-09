#!/bin/bash
# t/testc.sh -c -Du,-q -B static 2>&1 |tee c.log|grep FAIL
# for p in 5.6.2 5.8.8-nt 5.8.9d 5.10.1d 5.10.1d-nt 5.11.2d 5.11.2d-nt; do make -s clean; echo perl$p; perl$p Makefile.PL; t/testc.sh -q -O0 31; done
# quiet c only: t/testc.sh -q -O0
function help {
  echo "t/testc.sh [OPTIONS] [1-$ntests]"
  echo " -D<debugflags>     for O=C or O=CC. Default: C,-DcOACMSGpu,-v resp. CC,-DoOscprSql,-v"
  echo " -O<0-4>            optimization level"
  echo " -B<static|dynamic> pass to cc_harness"
  echo " -c                 continue on errors"
  echo " -k                 keep temp. files on PASS"
  echo " -E                 dump preprocessed source file with cc -E as _E.c"
  echo " -o                 orig. no -Mblib, use installed modules (5.6, 5.8)"
  echo " -a                 all. undo -Du. Unsilence scanning unused sub"
  echo " -q                 quiet"
  echo " -h                 help"
  echo "Without arguments try all $ntests tests. Without Option -Ox try -O0 to -O3 optimizations."
}

# use the actual perl from the Makefile (perl5.8.8, 
# perl5.10.0d-nt, perl5.11.0, ...)
PERL=`grep "^PERL =" Makefile|cut -c8-`
PERL=${PERL:-perl}

function init {
BASE=`basename $0`
# if $] < 5.9 you may want to remove -Mblib for testing the core lib. -o
#Mblib="`$PERL -e'print (($] < 5.009005) ? q() : q(-Mblib))'`"
Mblib=${Mblib:--Mblib} # B::C is now fully 5.6+5.8 backwards compatible
if [ -z $Mblib ]; then 
    VERS="${VERS}_global"; 
    OCMD="$PERL $Mblib -MO=C,-DcAC,"
    if [ $BASE = "testcc.sh" ]; then 
        OCMD="$PERL $Mblib -MO=CC,-DrOsplt,"
    fi
else
    OCMD="$PERL $Mblib -MO=C,-DcoOSAHGCMpu,-v,"
    if [ $BASE = "testcc.sh" ]; then
        OCMD="$PERL $Mblib -MO=CC,-DoOscprSql,-v,"
    fi
fi
OCMDO1="$(echo $OCMD|sed -e s/C,-D/C,-O1,-D/)"
OCMDO2="$(echo $OCMD|sed -e s/C,-D/C,-O2,-D/)"
OCMDO3="$(echo $OCMD|sed -e s/C,-D/C,-O3,-D/)"
OCMDO4="$(echo $OCMD|sed -e s/C,-D/C,-O4,-D/)"
CONT=
# 5.6: rather use -B static
#CCMD="$PERL script/cc_harness -g3"
# rest. -DALLOW_PERL_OPTIONS for -Dtlv
CCMD="$PERL script/cc_harness -d -g3 -Bdynamic -DALLOW_PERL_OPTIONS"  
LCMD=
# On some perls I also had to add $archlib/DynaLoader/DynaLoader.a to libs in Config.pm
}

function vcmd {
    test -n "$QUIET" || echo $*
    $*
}

function pass {
    #echo -n "$1 PASS "
    echo -e -n "\e[1;32mPASS \e[0;0m"
    shift
    echo $*
    echo
}
function fail {
    #echo -n "$1 FAIL "
    echo -e -n "\e[1;31mFAIL \e[0;0m"
    shift
    echo $*
    echo
}

function runopt {
    o=$1
    optim=$2
    suff="_o${optim}"
    if [ "$optim" == "0" ]; then suff=""; fi
    rm ${o}${suff} ${o}${suff}.c 2> /dev/null
    if [ $optim == 1 ]; then CMD=$OCMDO1
     else if [ $optim == 2 ]; then CMD=$OCMDO2
      else if [ $optim == 3 ]; then CMD=$OCMDO3
       else if [ $optim == 4 ]; then CMD=$OCMDO4
        else CMD=$OCMD
       fi
      fi
     fi
    fi
    vcmd ${CMD}-o${o}${suff}.c $o.pl
    test -z $CPP || vcmd $CCMD ${o}${suff}.c -c -E -o ${o}${suff}_E.c
    vcmd $CCMD ${o}${suff}.c $LCMD -o ${o}${suff}
    test -x ${o}${suff} || (test -z $CONT && exit)
    if [ -z "$QUIET" ]; then echo "./${o}${suff}"
    else echo -n "./${o}${suff} "
    fi
    res=$(./${o}${suff}) || fail "./${o}${suff}" "errcode $?"
    if [ "X$res" = "X${result[$n]}" ]; then
	test "X$res" = "X${result[$n]}" && pass "./${o}${suff}" "=> '$res'"
        if [ -z $KEEP ]; then rm ${o}${suff}_E.c ${o}${suff}.c ${o}${suff} 2>/dev/null; fi
        true
    else
	fail "./${o}${suff}" "=> '$str' => '$res'. Expected: '${result[$n]}'"
        false
    fi
}

function ctest {
    n=$1
    str=$2
    if [ $BASE = "testcc.sh" ]; then 
      o="cccode$n"
    else
      o="ccode$n"
    fi
    if [ -z "$str" ]; then
        if [ "$n" = "08" ]; then n=8; fi 
        if [ "$n" = "09" ]; then n=9; fi
	echo "${tests[${n}]}" > ${o}.pl
        str="${tests[${n}]}"
    else
	echo "$str" > ${o}.pl
    fi
    if [ $OPTIM -ge 0 ]; then
	runopt "$o" "$OPTIM"
    else # -1
	rm $o.c $o ${o}_o.c ${o}_o 2> /dev/null
	vcmd ${OCMD}-o$o.c $o.pl
        test -s $o.c || (echo "empty $o.c"; test -z $CONT && exit)
	test -z $CPP || vcmd $CCMD $o.c -c -E -o ${o}_E.c
	vcmd $CCMD $o.c $LCMD -o $o
	test -x $o || (test -z $CONT && exit)
	if [ -z "$QUIET" ]; then echo "./$o"
	else echo -n "./$o "
        fi
	res=$(./$o) || (fail "./${o}${suff}" "'$?' = $?"; test -z $CONT && exit)
	if [ "X$res" = "X${result[$n]}" ]; then
	    pass "./$o" "'$str' => '$res'"
            if [ -z $KEEP ]; then rm ${o}_E.c ${o}.c ${o} 2>/dev/null; fi
	    runopt $o 1 && \
	    runopt $o 2  && \
	    runopt $o 3
	    #runopt $o 4 && \
	    true
	else
	    fail "./$o" "'$str' => '$res' Expected: '${result[$n]}'"
	    test -z $CONT && exit
	fi
    fi
}

ntests=39
declare -a tests[$ntests]
declare -a result[$ntests]
ncctests=3
declare -a cctests[$((100+$ncctests))]
declare -a ccresult[$((100+$ncctests))]
tests[1]="print 'hi'"
result[1]='hi';
tests[2]="for (1,2,3) { print if /\d/ }"
result[2]='123';
tests[3]='$_ = "xyxyx"; %j=(1,2); s/x/$j{print("z")}/ge; print $_'
result[3]='zzz2y2y2';
tests[4]='$_ = "xyxyx"; %j=(1,2); s/x/$j{print("z")}/g; print $_'
result[4]='z2y2y2';
tests[5]='print split /a/,"bananarama"'
result[5]='bnnrm';
tests[6]="{package P; sub x {print 'ya'} x}"
result[6]='ya';
tests[7]='@z = split /:/,"b:r:n:f:g"; print @z'
result[7]='brnfg';
tests[8]='sub AUTOLOAD { print 1 } &{"a"}()'
result[8]='1';
tests[9]='my $l_i = 3; $x = sub { print $l_i }; &$x'
result[9]='3';
tests[10]='my $i_i = 1; 
my $foo = sub {
  $i_i = shift if @_
}; print $i_i; 
print &$foo(3),$i_i;'
result[10]='133';
# index: do fbm_compile or not
tests[11]='$x="Cannot use"; print index $x, "Can"'
result[11]='0';
tests[12]='my $i_i=6; eval "print \$i_i\n"'
result[12]='6';
tests[13]='BEGIN { %h=(1=>2,3=>4) } print $h{3}'
result[13]='4';
tests[14]='open our $T,"a"; print "ok";'
result[14]='ok';
# __DATA__ handles still broken non-threaded 5.10
tests[15]='print <DATA>
__DATA__
a
b'
result[15]='a
b';
tests[16]='BEGIN{tie @a, __PACKAGE__;sub TIEARRAY {bless{}} sub FETCH{1}}; print $a[1]'
result[16]='1';
tests[17]='my $i_ir=3; print 1 .. $i_ir'
result[17]='123';
# custom key sort
tests[18]='my $h = { a=>3, b=>1 }; print sort {$h->{$a} <=> $h->{$b}} keys %$h'
result[18]='ba';
# fool the sort optimizer by my $p, pp_sort works ok on CC
tests[19]='print sort { my $p; $b <=> $a } 1,4,3'
result[19]='431';
# not repro: something like this is broken in original 5.6 (Net::DNS::ZoneFile::Fast)
tests[20]='$a="abcd123";my $r=qr/\d/;print $a =~ $r;'
result[20]='1';
# broken on early alpha and 5.10: run-time labels.
tests[21]='sub skip_on_odd{next NUMBER if $_[0]% 2}NUMBER:for($i=0;$i<5;$i++){skip_on_odd($i);print $i;}'
result[21]='024';
# broken in original perl 5.6
tests[22]='my $fh; BEGIN { open($fh,"<","/dev/null"); } print "ok";';
result[22]='ok';
# broken in perl 5.8
tests[23]='package MyMod; our $VERSION = 1.3; print "ok";'
result[23]='ok'
# works in original perl 5.6, broken with latest B::C in 5.6, 5.8
tests[24]='sub level1{return(level2()?"fail":"ok")} sub level2{0} print level1();'
result[24]='ok'
# enforce custom ncmp sort and count it. fails as CC in all. How to enforce icmp?
# <=5.6 qsort needs two more passes here than >=5.8 merge_sort
tests[25]='print sort { print $i++," "; $b <=> $a } 1..4'
result[25]="0 1 2 3`$PERL -e'print (($] < 5.007) ? q( 4 5) : q())'` 4321";
# lvalue sub
tests[26]='sub a:lvalue{my $a=26; ${\(bless \$a)}}sub b:lvalue{${\shift}}; print ${a(b)}';
result[26]="26";
# xsub constants
tests[27]='use Fcntl; print "ok" if ( &Fcntl::O_WRONLY );'
result[27]='ok'
# require $fname
tests[28]='my($fname,$tmp_fh);while(!open($tmp_fh,">",($fname=q{cctest28_} . rand(999999999999)))){$bail++;die "Failed to create a tmp file after 500 tries" if $bail>500;}print {$tmp_fh} q{$x="ok";1;};close($tmp_fh);require $fname;unlink($fname);print $x;'
result[28]='ok'
# use test
tests[29]='use IO;print "ok"'
result[29]='ok'
# run-time context of .., fails in CC
tests[30]='@a=(4,6,1,0,0,1);sub range{(shift @a)..(shift @a)}print range();while(@a){print scalar(range())}'
result[30]='456123E0'
# AUTOLOAD w/o goto xsub
tests[31]='package MockShell;sub AUTOLOAD{my $p=$AUTOLOAD;$p=~s/.*:://;print(join(" ",$p,@_),";");} package main; MockShell::date();MockShell::who("am","i");MockShell::ls("-l");'
result[31]='date;who am i;ls -l;'
# CC entertry/jmpenv_jump/leavetry
tests[32]='eval{print "1"};eval{die 1};print "2\n";'
result[32]='12'
# C qr test was broken in 5.6 -- needs to load an actual file to test. See test 20.
# used to error with Can't locate object method "save" via package "U??WVS?-" (perhaps you forgot to load "U??WVS?-"?) at /usr/lib/perl5/5.6.2/i686-linux/B/C.pm line 676.
# fails with new constant only. still not repro (r-magic probably)
tests[33]='BEGIN{unshift @INC,("t");} use qr_loaded_module; print "ok"'
result[33]='ok'
# init of magic hashes. %ENV has e magic since a0714e2c perl.c  
# (Steven Schubiger      2006-02-03 17:24:49 +0100 3967) i.e. 5.8.9 but not 5.8.8
tests[34]='my $x=$ENV{TMPDIR};print "ok"'
result[34]='ok'
# method_named. fixed with 1.16
tests[35]='package dummy;sub meth{print "ok"};package main;dummy->meth'
result[35]='ok'
# HV self-ref
tests[36]='my ($rv, %hv); %hv = ( key => \$rv ); $rv = \%hv; print "ok";'
result[36]='ok'
# AV self-ref
tests[37]='my ($rv, @av); @av = ( \$rv ); $rv = \@av; print "ok";'
result[37]='ok'
# constant autoload loop crash test
tests[38]='for(1 .. 1024) { if (open(my $null_fh,"<","/dev/null")) { seek($null_fh,0,SEEK_SET); close($null_fh); $ok++; } }if ($ok == 1024) { print "ok"; }'
result[38]='ok'
# check re::is_regexp, and on 5.12 if being upgraded to SVt_REGEXP
usere="`$PERL -e'print (($] < 5.011) ? q(use re;) : q())'`"
tests[39]='{'$usere'$a=${qr//};$a=2;print ($] < 5.007?1:re::is_regexp(\$a))}'
result[39]='1'
# => Undefined subroutine &re::is_regexp with B-C-1.19, even with -ure


# from here on we test CC specifics only

# CC types and arith
tests[101]='my ($r_i,$i_i,$d_d)=(0,2,3.0); $r_i=$i_i*$i_i; $r_i*=$d_d; print $r_i;'
result[101]='12'
# CC cond_expr, stub, scope
tests[102]='if ($x eq "2"){}else{print "ok"}'
result[102]='ok'
# CC stringify, srefgen. TODO: use B; fails
tests[103]='require B; my $x=1e1; my $s="$x"; print ref B::svref_2object(\$s)'
result[103]='B::PV'


init

# 
# getopts for -q -k -E -Du,-q -v -O2, -a -c
while getopts "hqackoED:B:O:" opt
do
  if [ "$opt" = "q" ]; then 
    QUIET=1
    # O from 5.6 does not support -qq
    qq="`$PERL -e'print (($] < 5.007) ? q() : q(-qq,))'`"
    # replace -D*,-v by -q 
    OCMD="$(echo $OCMD    |sed -e 's/-D.*,//' -e 's/,-v,/,/' -e s/-MO=/-MO=$qq/)" 
    OCMDO1="$(echo $OCMDO1|sed -e 's/-D.*,//' -e 's/,-v,/,/' -e s/-MO=/-MO=$qq/)"
    OCMDO2="$(echo $OCMDO2|sed -e 's/-D.*,//' -e 's/,-v,/,/' -e s/-MO=/-MO=$qq/)"
    OCMDO3="$(echo $OCMDO3|sed -e 's/-D.*,//' -e 's/,-v,/,/' -e s/-MO=/-MO=$qq/)"
    OCMDO4="$(echo $OCMDO4|sed -e 's/-D.*,//' -e 's/,-v,/,/' -e s/-MO=/-MO=$qq/)"
    CCMD="$PERL script/cc_harness -q -g3 -Bdynamic -DALLOW_PERL_OPTIONS"
  fi
  if [ "$opt" = "o" ]; then Mblib=" "; init; fi
  if [ "$opt" = "c" ]; then CONT=1; fi
  if [ "$opt" = "k" ]; then KEEP=1; fi
  if [ "$opt" = "E" ]; then CPP=1; fi
  if [ "$opt" = "h" ]; then help; exit; fi
  # -D options: u,-q for quiet, no -D for verbose
  if [ "$opt" = "D" ]; then
    OCMD="$PERL $Mblib -MO=C,-D${OPTARG},"
    if [ $BASE = "testcc.sh" ]; then 
        OCMD="$PERL $Mblib -MO=CC,-D${OPTARG},"
    fi
  fi
  # -B dynamic or -B static
  if [ "$opt" = "B" ]; then 
    CCMD="$PERL script/cc_harness -d -g3 -B${OPTARG} -DALLOW_PERL_OPTIONS"
  fi
  if [ "$opt" = "O" ]; then OPTIM="$OPTARG"; fi
  if [ "$opt" = "a" ]; then # replace -Du, by -Do
    OCMD="$(echo $OCMD|sed -r -e 's/(-D.*)u,/\1o,/')" 
  fi
done
if [ -z $OPTIM ]; then OPTIM=-1; fi # all

if [ -z "$QUIET" ]; then
    make 
else
    make --silent >/dev/null
fi

# need to shift the options
while [ -n "$1" -a "${1:0:1}" = "-" ]; do shift; done

if [ -n "$1" ]; then
  while [ -n "$1" ]; do
    ctest $1
    shift
  done
else
  for b in $(seq -f"%02.0f" $ntests); do
    ctest $b
  done
  if [ $BASE = "testcc.sh" ]; then 
    for b in $(seq -f"%02.0f" 101 $(($ncctests+100))); do
      ctest $b
    done
  fi
fi

# 562  c:  15,25,27
# 58   c:  27,29_i
# 58  cc:  15,18,21,25,26_o,27,29
# 510  c:  15
# 510 cc:  11,15,29
# 511  c:  11,15,16,29

#  http://www.nntp.perl.org/group/perl.perl5.porters/2005/07/msg103315.html
#  FAIL for B::CC should be covered by test 18
