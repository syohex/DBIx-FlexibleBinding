#!perl -T
use 5.006;
use strict;
use warnings;
use Data::Dumper;
use Params::Callbacks qw(callback);
use Test::More tests => 1;

$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 0;

BEGIN
{
    use_ok('DBIx::FlexibleBinding') || print "Bail out!\n";
}

diag("Testing DBIx::FlexibleBinding $DBIx::FlexibleBinding::VERSION, Perl $], $^X");

{
    #    my $dbh = DBIx::FlexibleBinding->connect( 'dbi:SQLite:dbname=test.db', undef, undef, { RaiseError => 1 } )
    #      or die $DBI::errstr;

    my $dbh =
      DBIx::FlexibleBinding->connect( 'dbi:mysql:database=test;host=127.0.0.1', 'test', 'test', { RaiseError => 1 } )
      or die $DBI::errstr;

    my $stmt =
      'CREATE TABLE IF NOT EXISTS TEST (id INT PRIMARY KEY NOT NULL, name CHAR(32) NOT NULL, value TEXT NOT NULL)';

    my $rc = $dbh->do($stmt);

    if ( $rc < 0 )
    {
        die $DBI::errstr;
    }
    else
    {
        print "Table created successfully\n";
    }

    $dbh->do('DELETE FROM test');

    {
        my $sth_q = $dbh->prepare('INSERT INTO test (id, name, value) VALUES (?1, ?2, ?3)');
        eval { $sth_q->execute( 1, 'ONE', 'One' ) };
    }

    {
        my $sth_n = $dbh->prepare('INSERT INTO test (id, name, value) VALUES (:1, :2, :2)');
        eval { $sth_n->execute( [ 2, 'TWO', 'Two' ] ) };
    }

    {
        my $sth_w = $dbh->prepare('INSERT INTO test (id, name, value) VALUES (@id, @name, @value)');
        eval { $sth_w->execute( [ '@id' => 3, '@name' => 'THREE', '@value' => 'Three' ] ) };
    }

    {
        eval { $dbh->do( 'INSERT INTO test (id, name, value) VALUES (?, ?, ?)', undef, 4, 'FOUR', 'Four' ) };
    }

    {
        eval { $dbh->do( 'INSERT INTO test (id, name, value) VALUES (:1, :2, :3)', undef, [ 5, 'FIVE', 'Five' ] ) };
    }

    {
        eval {
            $dbh->do( 'INSERT INTO test (id, name, value) VALUES (:id, :name, :value)',
                undef, { id => 6, name => 'SIX', value => 'Six' } );
        };
    }

    {
        my $sth = $dbh->prepare('SELECT * FROM test');
        $sth->execute_and_fetch_records(callback {
            say STDERR Dumper($_);
            return $_[0]
        } );
    }
    $dbh->disconnect();
}
