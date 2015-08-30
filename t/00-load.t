#!perl
use 5.006;
use strict;
use warnings;
use Data::Dumper;
use Params::Callbacks qw(callback);
use JSON ();
use Test::More;

$Data::Dumper::Terse  = 1;
$Data::Dumper::Indent = 0;

BEGIN
{
    use_ok('DBIx::FlexibleBinding') || print "Bail out!\n";
}

diag "Testing DBIx::FlexibleBinding $DBIx::FlexibleBinding::VERSION, Perl $], $^X";

my $drivers = 'CSV|SQLite|mysql';
my @drivers = grep { /^(?:$drivers)$/ } DBI->available_drivers();

SKIP:
{
    unless (@drivers)
    {
        my $list_of_drivers = join( ', ', map { "DBD::$_" } split( /\|/, $drivers ) );
        skip "Tests require at least one of these DBI drivers to execute: $list_of_drivers", 1;
    }

    # There be giants:
    #
    # My test data originates from a MySQL conversion of CCP's EVE Online Static Data Export, with the conversion
    # being the result of Fuzzwork's hard work. My test data is a subset of that conversion. For more information
    # about EVE Online and Fuzzwork's excellent resource, check them out at the following links:
    #
    # - http://www.eveonline.com/
    # - https://www.fuzzwork.co.uk/
    # - https://www.fuzzwork.co.uk/dump/
    #
    # The test data set is a 7,929 record table containing data for EVE's 7,929 in-game solar systems, and it's
    # fairly large!
    open my $json_test_data_fh, '<:encoding(UTF-8)', './mapsolarsystems.json'
      or die "Unable to open ./mapsolarsystems test data";
    my $json_test_data = do { local $/ = <$json_test_data_fh> };
    close $json_test_data_fh;
    my $test_data = JSON::decode_json($json_test_data);
    my $create    = << 'EOF';
CREATE TABLE mapsolarsystems (
  regionID INT(11) DEFAULT NULL,
  constellationID INT(11) DEFAULT NULL,
  solarSystemID INT(11) NOT NULL,
  solarSystemName varchar(100) DEFAULT NULL,
  x DOUBLE DEFAULT NULL,
  y DOUBLE DEFAULT NULL,
  z DOUBLE DEFAULT NULL,
  xMin DOUBLE DEFAULT NULL,
  xMax DOUBLE DEFAULT NULL,
  yMin DOUBLE DEFAULT NULL,
  yMax DOUBLE DEFAULT NULL,
  zMin DOUBLE DEFAULT NULL,
  zMax DOUBLE DEFAULT NULL,
  luminosity DOUBLE DEFAULT NULL,
  border TINYINT(1) DEFAULT NULL,
  fringe TINYINT(1) DEFAULT NULL,
  corridor TINYINT(1) DEFAULT NULL,
  hub TINYINT(1) DEFAULT NULL,
  international TINYINT(1) DEFAULT NULL,
  regional TINYINT(1) DEFAULT NULL,
  constellation TINYINT(1) DEFAULT NULL,
  security DOUBLE DEFAULT NULL,
  factionID INT(11) DEFAULT NULL,
  radius DOUBLE DEFAULT NULL,
  sunTypeID INT(11) DEFAULT NULL,
  securityClass varchar(2) DEFAULT NULL,
  PRIMARY KEY (solarSystemID)
)
EOF

    # Need the column numbers for each column
    my $count                   = 0;
    my @headings                = @{ shift(@$test_data) };
    my $columns                 = join( ', ', @headings );
    my %columns                 = map { ( $_ => $count++ ) } @headings;
    my $positional_placeholders = join( ', ', map { "?" } @headings );
    my $n1_placeholders         = join( ', ', map { ":@{[1 + $columns{$_}]}" } @headings );
    my $n2_placeholders         = join( ', ', map { "?@{[1 + $columns{$_}]}" } @headings );
    my $name1_placeholders      = join( ', ', map { ":$_" } @headings );
    my $name2_placeholders      = join( ', ', map { "\@$_" } @headings );

    for my $driver (@drivers)
    {
      SKIP:
        {
            my @test_data = @{$test_data};
            my ( $rv, $create_copy, $dbh, $dsn, @user, $attr ) =
              ( undef, undef, undef, undef, (), { RaiseError => 1 } );

            if ( $driver eq 'CSV' )
            {
                ( $dsn, @user, $attr ) = ( "dbi:$driver:", '', '', { f_dir => '.' } );
                $create_copy = $create;
                s/ DEFAULT NULL//g, s/ DOUBLE/ REAL/g, s/ (?:TINYINT|INT)/ INTEGER/g for $create_copy;
                $dbh = DBIx::FlexibleBinding->connect( $dsn, @user, $attr );
            }
            elsif ( $driver eq 'SQLite' )
            {
                ( $dsn, @user, $attr ) = ( "dbi:$driver:test.db", '', '', {} );
                $create_copy = $create;
                $dbh = DBIx::FlexibleBinding->connect( $dsn, @user, $attr );
            }
            else
            {
                ( $dsn, @user, $attr ) =
                  ( "dbi:$driver:test;host=127.0.0.1", $ENV{MYSQL_TEST_USER}, $ENV{MYSQL_TEST_PASS}, {} );
                $dbh = DBIx::FlexibleBinding->connect( $dsn, @user, $attr );
                $create_copy = $create;
            }

            skip "Connection to datasource failed ($dsn); tests skipped for $driver", 1
              unless defined $dbh;

            # Yay, we got a connection!
            is( ref($dbh), 'DBIx::FlexibleBinding::db', "Testing DBD\::$driver ($dsn)" );

            #            # Drop the "mapsolarsystems" table
            #            $rv = $dbh->do('DROP TABLE IF EXISTS mapsolarsystems');
            #            if ( $driver eq 'CSV' )
            #            {
            #                is( $rv, -1, "drop" );    # Table drop won't do anything useful, delete the table's CSV file manually
            #                unlink './mapsolarsystems';
            #            }
            #            else
            #            {
            #                is( $rv, '0E0', "drop" );    # Table was dropped
            #            }
            #
            #            # Recreate the "mapsolarsystems" table using a create statement sanitised for the driver
            #            $rv = $dbh->do($create_copy);
            #            is( $rv, '0E0', "create" );      # Table was created
            #
            #            # Populate the "mapsolarsystems" table
            #            my $count = 0;
            #            while (@test_data)
            #            {
            #                $count++;
            #                if ( $count > 881 )
            #                {
            #                    $count -= 1;
            #                    last;
            #                }
            #                my $row = shift(@test_data);
            #                $rv = $dbh->do( "INSERT INTO mapsolarsystems ($columns) VALUES ($positional_placeholders)", undef, @$row );
            #                last unless $rv == 1;
            #            }
            #            is( $count, 881, "insert ? ( VALUES )" );    # do/INSERTs successful using positionals and list
            #
            #            while (@test_data)
            #            {
            #                $count++;
            #                if ( $count > 1362 )
            #                {
            #                    $count -= 1;
            #                    last;
            #                }
            #                my $row = shift(@test_data);
            #                $rv = $dbh->do( "INSERT INTO mapsolarsystems ($columns) VALUES ($n1_placeholders)", undef, @$row );
            #                last unless $rv == 1;
            #            }
            #            is( $count, 1362, "insert :NUMBER ( VALUES )" );    # do/INSERTs successful using :N and list
            #
            #            while (@test_data)
            #            {
            #                $count++;
            #                if ( $count > 1762 )
            #                {
            #                    $count -= 1;
            #                    last;
            #                }
            #                my $row = shift(@test_data);
            #                $rv = $dbh->do( "INSERT INTO mapsolarsystems ($columns) VALUES ($n1_placeholders)", undef, $row );
            #                last unless $rv == 1;
            #            }
            #            is( $count, 1762, "insert :NUMBER [ VALUES ]" );    # do/INSERTs successful using :N and anonymous list
            #
            #            while (@test_data)
            #            {
            #                $count++;
            #                if ( $count > 2243 )
            #                {
            #                    $count -= 1;
            #                    last;
            #                }
            #                my $row = shift(@test_data);
            #                $rv = $dbh->do( "INSERT INTO mapsolarsystems ($columns) VALUES ($n2_placeholders)", undef, @$row );
            #                last unless $rv == 1;
            #            }
            #            is( $count, 2243, "insert ?NUMBER ( VALUES )" );    # do/INSERTs successful using ?N and list
            #
            #            while (@test_data)
            #            {
            #                $count++;
            #                if ( $count > 2643 )
            #                {
            #                    $count -= 1;
            #                    last;
            #                }
            #                my $row = shift(@test_data);
            #                $rv = $dbh->do( "INSERT INTO mapsolarsystems ($columns) VALUES ($n2_placeholders)", undef, $row );
            #                last unless $rv == 1;
            #            }
            #            is( $count, 2643, "insert ?NUMBER [ VALUES ]" );    # do/INSERTs successful using ?N and anonymous list
            #
            #            while (@test_data)
            #            {
            #                $count++;
            #                if ( $count > 3524 )
            #                {
            #                    $count -= 1;
            #                    last;
            #                }
            #                my $row = shift(@test_data);
            #                my @data = map { $_ => $row->[ $columns{$_} ] } @headings;
            #                $rv = $dbh->do( "INSERT INTO mapsolarsystems ($columns) VALUES ($name1_placeholders)", undef, @data );
            #                last unless $rv == 1;
            #            }
            #            is( $count, 3524, "insert :NAME ( KEY-VALUE PAIRS )" );    # do/INSERTs successful using :NAME with list
            #
            #            while (@test_data)
            #            {
            #                $count++;
            #                if ( $count > 4405 )
            #                {
            #                    $count -= 1;
            #                    last;
            #                }
            #                my $row = shift(@test_data);
            #                my @data = map { $_ => $row->[ $columns{$_} ] } @headings;
            #                $rv = $dbh->do( "INSERT INTO mapsolarsystems ($columns) VALUES ($name1_placeholders)", undef, [@data] );
            #                last unless $rv == 1;
            #            }
            #            is( $count, 4405, "insert :NAME [ KEY-VALUE PAIRS ]" );    # do/INSERTs successful using :NAME with anonymous list
            #
            #            while (@test_data)
            #            {
            #                $count++;
            #                if ( $count > 5286 )
            #                {
            #                    $count -= 1;
            #                    last;
            #                }
            #                my $row = shift(@test_data);
            #                my @data = map { $_ => $row->[ $columns{$_} ] } @headings;
            #                $rv = $dbh->do( "INSERT INTO mapsolarsystems ($columns) VALUES ($name1_placeholders)", undef, {@data} );
            #                last unless $rv == 1;
            #            }
            #            is( $count, 5286, "insert :NAME { KEY-VALUE PAIRS }" );    # do/INSERTs successful using :NAME with anonymous hash
            #
            #            while (@test_data)
            #            {
            #                $count++;
            #                if ( $count > 6167 )
            #                {
            #                    $count -= 1;
            #                    last;
            #                }
            #                my $row = shift(@test_data);
            #                my @data = map { '@' . $_ => $row->[ $columns{$_} ] } @headings;
            #                $rv = $dbh->do( "INSERT INTO mapsolarsystems ($columns) VALUES ($name2_placeholders)", undef, @data );
            #                last unless $rv == 1;
            #            }
            #            is( $count, 6167, "insert \@NAME ( KEY-VALUE PAIRS )" );    # do/INSERTs successful using @NAME with anonymous list
            #
            #            while (@test_data)
            #            {
            #                $count++;
            #                if ( $count > 7048 )
            #                {
            #                    $count -= 1;
            #                    last;
            #                }
            #                my $row = shift(@test_data);
            #                my @data = map { '@' . $_ => $row->[ $columns{$_} ] } @headings;
            #                $rv = $dbh->do( "INSERT INTO mapsolarsystems ($columns) VALUES ($name2_placeholders)", undef, [@data] );
            #                last unless $rv == 1;
            #            }
            #            is( $count, 7048, "insert \@NAME [ KEY-VALUE PAIRS ]" );    # do/INSERTs successful using @NAME with anonymous list
            #
            #            while (@test_data)
            #            {
            #                $count++;
            #                if ( $count > 7929 )
            #                {
            #                    $count -= 1;
            #                    last;
            #                }
            #                my $row = shift(@test_data);
            #                my @data = map { '@' . $_ => $row->[ $columns{$_} ] } @headings;
            #                $rv = $dbh->do( "INSERT INTO mapsolarsystems ($columns) VALUES ($name2_placeholders)", undef, {@data} );
            #                last unless $rv == 1;
            #            }
            #            is( $count, 7929, "insert \@NAME { KEY-VALUE PAIRS }" );    # do/INSERTs successful using @NAME with anonymous hash
            #
            #            # Prepare, execute, fetch cycle...
            $DBIx::FlexibleBinding::DEFAULT_AUTO_BIND = 0;    # Disable auto binding globabally to keep things as standard as possible

            # First, some really basic checks...
            my $sql = 'SELECT COUNT(*) AS count FROM mapsolarsystems';

            {
                my $sth = $dbh->prepare($sql);
                $sth->execute();
                my @result = $sth->fetchrow_array();
                is( $result[0], 7929, 'prepare, execute, fetchrow_array' );
            }

            {
                my $sth = $dbh->prepare($sql);
                $sth->execute();
                my $result = $sth->fetchrow_arrayref();
                is( $result->[0], 7929, 'prepare, execute, fetchrow_arrayref' );
            }

            {
                my $sth = $dbh->prepare($sql);
                $sth->execute();
                my $result = $sth->fetchrow_hashref();
                is( $result->{count}, 7929, 'prepare, execute, fetchrow_hashref' );
            }

            {
                my $sth = $dbh->prepare($sql);
                $sth->execute();
                my $result = $sth->fetchall_arrayref();
                is_deeply( $result, [ ['7929'] ], 'prepare, execute, fetchall_arrayref' );
            }

            {
                my $sth = $dbh->prepare($sql);
                $sth->execute();
                my $result = $sth->fetchall_arrayref( {} );
                is_deeply( $result, [ { count => '7929' } ], 'prepare, execute, fetchall_arrayref({})' );
            }

            {
                my @result = $dbh->selectrow_array($sql);
                is( $result[0], 7929, 'selectrow_array' );
            }

            {
                my $result = $dbh->selectrow_arrayref($sql);
                is( $result->[0], 7929, 'selectrow_arrayref' );
            }

            {
                my $result = $dbh->selectrow_hashref($sql);
                is( $result->{count}, 7929, 'selectrow_hashref' );
            }

            {
                my $result = $dbh->selectall_arrayref($sql);
                is_deeply( $result, [ ['7929'] ], 'selectall_arrayref' );
            }

            {
                my $result = $dbh->selectall_arrayref($sql, { Slice => {} });
                is_deeply( $result, [ { count => '7929' } ], 'selectall_arrayref({Slice => {}})' );
            }

            $dbh->disconnect();

            #            if ( $driver eq 'CSV' )
            #            {
            #                unlink './mapsolarsystems';
            #            }
            #            elsif ( $driver eq 'SQLite' )
            #            {
            #                unlink './test.db';
            #            }
            #            else
            #            {
            #                # Nothing to clean up
            #            }
        }
    }
}

done_testing();

#my $dbh = DBIx::FlexibleBinding->connect( 'dbi:SQLite:dbname=test.db', '', '', { RaiseError => 1 } );
#$dbh->disconnect();
#{
#    my $dbh = DBIx::FlexibleBinding->connect( 'dbi:mysql:test;hostname=127.0.0.1', 'test', 'test', { RaiseError => 1 } )
#      or die $DBI::errstr;
#    #$DBIx::FlexibleBinding::DEFAULT_DBI_FETCH_METHOD = 'fetchrow_hashref';
#    my $sth = $dbh->prepare('SELECT * FROM mapsolarsystems WHERE security >= 1 AND regional = 1');
#    $sth->execute();
#    my $results = $sth->fetch_all();
#    print Dump( $results );
#
#    $dbh->disconnect();
#}
