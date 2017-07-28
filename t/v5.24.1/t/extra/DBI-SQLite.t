use DBI;

print qq[1..2\n];

my $file = q{/tmp/mytest.sqlite};
unlink $file if -e $file;

my $dbh = DBI->connect( "dbi:SQLite:dbname=$dbfile", "", "", { RaiseError => 1 } );
$dbh->do(
    "create table mytable (
  `id` int(10) NOT NULL,
  `value` varchar(128) NOT NULL DEFAULT '',
   PRIMARY KEY (`id`)
)
"
) or die $!;

{
    my $sth = $dbh->prepare("INSERT INTO mytable VALUES (?, ?)");
    $sth->execute( 1, 'ok 1 - one' );
    $sth->execute( 2, 'ok 2 - two' );
    $sth->finish;
}

{
    my $stmt = qq(SELECT id, value from mytable);
    my $sth  = $dbh->prepare($stmt);
    $rv = $sth->execute() or die $DBI::errstr;
    print $DBI::errstr unless $rv >= 0;

    while ( my @row = $sth->fetchrow_array() ) {
        print "$row[1]\n";
    }

}

$dbh->disconnect;

