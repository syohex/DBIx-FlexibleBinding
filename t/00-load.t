#!perl -T
use 5.006;
use strict;
use warnings;
use Data::Dumper;
use Params::Callbacks qw(callback);
use JSON::Syck qw(Dump);
use Test::More tests => 1;

$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 0;

BEGIN
{
    use_ok('DBIx::FlexibleBinding') || print "Bail out!\n";
}

diag("Testing DBIx::FlexibleBinding $DBIx::FlexibleBinding::VERSION, Perl $], $^X");

{
    my $dbh = DBIx::FlexibleBinding->connect( 'dbi:mysql:test;hostname=127.0.0.1', 'test', 'test', { RaiseError => 1 } )
      or die $DBI::errstr;
    #$DBIx::FlexibleBinding::DEFAULT_DBI_FETCH_METHOD = 'fetchrow_hashref';
    my $sth = $dbh->prepare('SELECT * FROM mapsolarsystems WHERE security >= 1 AND regional = 1');
    $sth->execute();
    my $results = $sth->fetch_all();
    print Dump( $results );

    $dbh->disconnect();
}
