package DBIx::FlexibleBinding;

use 5.006;
use strict;
use warnings;
use MRO::Compat 'c3';

use DBI ();
use namespace::clean;
our $VERSION                       = '0.000001';
our @ISA                           = 'DBI';
our $DEFAULT_DBI_FETCH_METHOD      = 'fetchrow_arrayref';
our @DEFAULT_DBI_FETCH_METHOD_ARGS = ();

sub _dbix_set_err
{
    my ( $handle, @args ) = @_;
    return $handle->set_err( $DBI::stderr, @args );
}

sub connect
{
    my ( $invocant, $dsn, $user, $pass, $attr ) = @_;
    $attr = {} unless defined $attr;
    $attr->{RootClass} = __PACKAGE__ unless defined $attr->{RootClass};
    return $invocant->SUPER::connect( $dsn, $user, $pass, $attr );
}

package    # Hide from PAUSE
  DBIx::FlexibleBinding::db;

use List::MoreUtils qw(any);
use Params::Callbacks qw(callbacks);
use namespace::clean;

our @ISA = 'DBI::db';

sub prepare
{
    my ( $dbh, $stmt, @args ) = @_;
    my @params;

    if ( $stmt =~ /:\w+\b/ )
    {
        @params = ( $stmt =~ /:(\w+)\b/g );
        $stmt =~ s/:\w+\b/?/g;
    }
    elsif ( $stmt =~ /\@\w+\b/ )
    {
        @params = ( $stmt =~ /(\@\w+)\b/g );
        $stmt =~ s/\@\w+\b/?/g;
    }
    elsif ( $stmt =~ /\?\d+\b/ )
    {
        @params = ( $stmt =~ /\?(\d+)\b/g );
        $stmt =~ s/\?\d+\b/?/g;
    }

    my $sth = $dbh->SUPER::prepare( $stmt, @args ) or return;

    if (@params)
    {
        $sth->{private_auto_binding}              = 1;
        $sth->{private_numeric_placeholders_only} = ( any { /\D/ } @params ) ? 0 : 1;
        $sth->{private_param_counts}              = { map { $_ => 0 } @params };
        $sth->{private_param_order}               = \@params;
        $sth->{private_param_counts}{$_}++ for @params;
    }

    return $sth;
}

sub do
{
    my ( $dbh, $stmt, $attr, @bind_values ) = @_;
    my $sth = $dbh->prepare( $stmt, $attr ) or return;
    return $sth->execute(@bind_values);
}

sub execute_and_fetch_records
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    unless ( ref($sth) )
    {
        my $attr = ref( $bind_values[0] ) ? shift(@bind_values) : undef;
        $sth = $dbh->prepare( $sth, $attr );
    }

    my $rows;
    if ( $sth->auto_bind() )
    {
        $sth->_bind(@bind_values);
        $rows = $sth->execute();
    }
    else
    {
        $rows = $sth->execute(@bind_values);
    }

    return unless $rows > 0;

    return $sth->fetch_records(@$callbacks);
}

sub execute_and_fetch_record
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    unless ( ref($sth) )
    {
        my $attr = ref( $bind_values[0] ) ? shift(@bind_values) : undef;
        $sth = $dbh->prepare( $sth, $attr );
    }

    my $rows;
    if ( $sth->auto_bind() )
    {
        $sth->_bind(@bind_values);
        $rows = $sth->execute();
    }
    else
    {
        $rows = $sth->execute(@bind_values);
    }

    return unless $rows > 0;

    return $sth->fetch_record(@$callbacks);
}

package    # Hide from PAUSE
  DBIx::FlexibleBinding::st;

BEGIN
{
    *_dbix_set_err                 = \&DBIx::FlexibleBinding::_dbix_set_err;
    *DEFAULT_DBI_FETCH_METHOD      = \$DBIx::FlexibleBinding::DEFAULT_DBI_FETCH_METHOD;
    *DEFAULT_DBI_FETCH_METHOD_ARGS = \@DBIx::FlexibleBinding::DEFAULT_DBI_FETCH_METHOD_ARGS;
}

use Params::Callbacks qw(callbacks);
use Scalar::Util qw(reftype);
use namespace::clean;

our @ISA = 'DBI::st';

sub _bind_array_ref
{
    my ( $sth, $array_ref ) = @_;
    for ( my $n = 0 ; $n < @$array_ref ; $n++ )
    {
        $sth->bind_param( $n + 1, $array_ref->[$n] );
    }
    return $sth;
}

sub _bind_hash_ref
{
    my ( $sth, $hash_ref ) = @_;
    $sth->bind_param( $_, $hash_ref->{$_} ) for keys %$hash_ref;
    return $sth;
}

sub _bind
{
    my ( $sth, @args ) = @_;
    return $sth unless @args;

    return $sth->_bind_array_ref( \@args )
      unless @{ $sth->{private_param_order} };

    my $ref = ( @args == 1 ) && reftype( $args[0] );
    if ($ref)
    {

        return _dbix_set_err( $sth, 'A reference to either a HASH or ARRAY was expected for autobind operation' )
          unless $ref eq 'HASH' || $ref eq 'ARRAY';

        if ( $ref eq 'HASH' )
        {
            $sth->_bind_hash_ref( $args[0] );
        }
        else
        {
            if ( $sth->{private_numeric_placeholders_only} )
            {
                $sth->_bind_array_ref( $args[0] );
            }
            else
            {
                $sth->_bind_hash_ref( { @{ $args[0] } } );
            }
        }
    }
    else
    {
        if (@args)
        {
            if ( $sth->{private_numeric_placeholders_only} )
            {
                $sth->_bind_array_ref( \@args );
            }
            else
            {
                $sth->_bind_hash_ref( {@args} );
            }
        }
    }

    return $sth;
}

sub auto_bind
{
    my ( $sth, $bool ) = @_;

    if ( @_ > 1 )
    {
        $sth->{private_auto_binding} = $bool ? 1 : 0;
        return $sth;
    }

    return $sth->{private_auto_binding};
}

sub bind_param
{
    my ( $sth, $param, $value, $attr ) = @_;

    return _dbix_set_err( $sth, "Binding identifier is missing" )
      unless defined($param) && $param;

    return _dbix_set_err( $sth, 'Binding identifier "' . $param . '" is malformed' )
      if $param =~ /[^\@\w]/;

    return $sth->SUPER::bind_param( $param, $value, $attr )
      unless @{ $sth->{private_param_order} };

    my $bind_rv = undef;
    my $pos     = 0;
    my $count   = 0;

    for my $name_or_number ( @{ $sth->{private_param_order} } )
    {
        $pos += 1;
        next
          if $name_or_number ne $param;

        $count += 1;
        last
          if $count > $sth->{private_param_counts}{$param};

        $bind_rv = $sth->SUPER::bind_param( $pos, $value, $attr );
    }

    return $bind_rv;
}

sub execute
{
    my ( $sth, @bind_values ) = @_;

    my $rows;
    if ( $sth->auto_bind() )
    {
        $sth->_bind(@bind_values);
        $rows = $sth->SUPER::execute();
    }
    else
    {
        $rows = $sth->SUPER::execute(@bind_values);
    }

    return ( $rows == 0 ) ? '0E0' : $rows;
}

sub fetch_records
{
    my ( $callbacks, $sth ) = &callbacks;
    my @result;
    local $_;
    while ( my $row = $sth->$DEFAULT_DBI_FETCH_METHOD(@DEFAULT_DBI_FETCH_METHOD_ARGS) )
    {
        push @result, $callbacks->transform( $_ = $row );
    }
    return wantarray ? @result : \@result;
}

sub fetch_record
{
    my ( $callbacks, $sth ) = &callbacks;
    my $fetch = my @result;
    my $row   = $sth->$sth->$DEFAULT_DBI_FETCH_METHOD(@DEFAULT_DBI_FETCH_METHOD_ARGS);
    $sth->finish();
    local $_;
    push @result, $callbacks->transform( $_ = $row ) if $row;
    return $result[0];
}

sub execute_and_fetch_records
{
    my ( $callbacks, $sth, @bind_values ) = &callbacks;

    my $rows;
    if ( $sth->auto_bind() )
    {
        $sth->_bind(@bind_values);
        $rows = $sth->execute();
    }
    else
    {
        $rows = $sth->execute(@bind_values);
    }

    return unless $rows > 0;

    return $sth->fetch_records(@$callbacks);
}

sub execute_and_fetch_record
{
    my ( $callbacks, $sth, @bind_values ) = &callbacks;

    my $rows;
    if ( $sth->auto_bind() )
    {
        $sth->_bind(@bind_values);
        $rows = $sth->execute();
    }
    else
    {
        $rows = $sth->execute(@bind_values);
    }

    return unless $rows > 0;

    return $sth->fetch_record(@$callbacks);
}

1;

__END__

=head1 NAME

DBIx::FlexibleBinding - flexible parameter binding and record fetching

=head1 SYNOPSIS

    # Introducing the module...
    use DBIx::FlexibleBinding;
    my $dbh = DBIx::FlexibleBinding->connect($dsn, $user, $pass, \%attributes);

    # Or, alteratively...
    use DBI;
    my $dbh = DBI->connect($dsn, $user, $pass, { %attributes, RootClass => 'DBIx::FlexibleBinding' }); 
    
    # Prepare using :NAME scheme...
    my $sth = $dbh->prepare(<< 'EOF');
    SELECT * 
      FROM cakes 
     WHERE type    = :type    
       AND colour  = :colour  
       AND flavour = :flavour
    EOF
    
    # Execute (any of the are valid for this named scheme)...
    my $row_count = $sth->execute(type => 'sponge', colour => 'yellow', flavour => 'yummy');
    my $row_count = $sth->execute([ type => 'sponge', colour => 'yellow', flavour => 'yummy' ]);
    my $row_count = $sth->execute({ type => 'sponge', colour => 'yellow', flavour => 'yummy' });

    # Prepare using @NAME scheme...
    my $sth = $dbh->prepare(<< 'EOF');
    SELECT * 
      FROM cakes 
     WHERE type    = @type    
       AND colour  = @colour  
       AND flavour = @flavour
    EOF
    
    # Execute (any of the are valid for this named scheme)...
    my $row_count = $sth->execute('@type' => 'sponge', '@colour' => 'yellow', '@flavour' => 'yummy');
    my $row_count = $sth->execute([ '@type' => 'sponge', '@colour' => 'yellow', '@flavour' => 'yummy' ]);
    my $row_count = $sth->execute({ '@type' => 'sponge', '@colour' => 'yellow', '@flavour' => 'yummy' });

    # Prepare using :N scheme...
    my $sth = $dbh->prepare(<< 'EOF');
    SELECT * 
      FROM cakes 
     WHERE type    = :1    
       AND colour  = :2  
       AND flavour = :3
    EOF
    
    # Execute (any of the are valid for this numeric scheme)...
    my $row_count = $sth->execute('sponge', 'yellow', 'yummy');
    my $row_count = $sth->execute([ 'sponge', 'yellow', 'yummy' ]);

    # Prepare using ?N scheme...
    my $sth = $dbh->prepare(<< 'EOF');
    SELECT * 
      FROM cakes 
     WHERE type    = ?1    
       AND colour  = ?2  
       AND flavour = ?3
    EOF
    
    # Execute (any of the are valid for this numeric scheme)...
    my $row_count = $sth->execute('sponge', 'yellow', 'yummy');
    my $row_count = $sth->execute([ 'sponge', 'yellow', 'yummy' ]);

    # Prepare using ? scheme...
    my $sth = $dbh->prepare(<< 'EOF');
    SELECT * 
      FROM cakes 
     WHERE type    = ?    
       AND colour  = ?  
       AND flavour = ?
    EOF
    
    # Execute (any of the are valid for this positional scheme)...
    my $row_count = $sth->execute('sponge', 'yellow', 'yummy');
    my $row_count = $sth->execute([ 'sponge', 'yellow', 'yummy' ]);

    # Binding is automatic by default to promote the Perl virtue 
    # of laziness!
    # 
    # Those with a penchant for masochism may switch that nonsense 
    # off using the C<auto_bind> method...
    my $sth = $dbh->prepare(<< 'EOF')->auto_bind(0);
    SELECT * 
      FROM cakes 
     WHERE type    = :type    
       AND colour  = :colour  
       AND flavour = :flavour
    EOF
    
    $sth->bind_param('type', 'sponge');
    $sth->bind_param('colour', 'yellow');
    $sth->bind_param('flavour', 'yummy');
    $sth->execute();
    
    # Manual binding with numeric or positional parameters...
    my $sth = $dbh->prepare(<< 'EOF')->auto_bind(0);
    SELECT * 
      FROM cakes 
     WHERE type    = :1    
       AND colour  = :2  
       AND flavour = :3
    EOF
    
    $sth->bind_param(1, 'sponge');
    $sth->bind_param(2, 'yellow');
    $sth->bind_param(3, 'yummy');
    $sth->execute();

    # Using the "do" method...
    $dbh->do('INSERT INTO cakes (type, colour, flavour) VALUES (?, ?, ?)', undef, 
        'sponge', 'yellow', 'yummy');
    $dbh->do('INSERT INTO cakes (type, colour, flavour) VALUES (?, ?, ?)', undef, 
        [ 'sponge', 'yellow', 'yummy' ]);
    $dbh->do('INSERT INTO cakes (type, colour, flavour) VALUES (:1, :2, :3)', undef, 
        'sponge', 'yellow', 'yummy');
    $dbh->do('INSERT INTO cakes (type, colour, flavour) VALUES (:1, :2, :3)', undef, 
        [ 'sponge', 'yellow', 'yummy' ]);
    $dbh->do('INSERT INTO cakes (type, colour, flavour) VALUES (:type, :colour, :flavour)', undef, 
        type => 'sponge', colour => 'yellow', flavour => 'yummy');
    $dbh->do('INSERT INTO cakes (type, colour, flavour) VALUES (:type, :colour, :flavour)', undef, 
        [ type => 'sponge', colour => 'yellow', flavour => 'yummy' ]);
    $dbh->do('INSERT INTO cakes (type, colour, flavour) VALUES (:type, :colour, :flavour)', undef, 
        { type => 'sponge', colour => 'yellow', flavour => 'yummy' });
    
=head1 DESCRIPTION

This module subclasses the DBI to provide the developer with greater 
flexibility in their choice of parameter placeholder schemes. In addition
to the standard positional C<?> placeholders, this module supports other
popular schemes:

=over 2

=item * :N (numeric, e.g. C<:1>)

=item * ?N (numeric, e.g. C<?1>)

=item * :NAME (named, e.g. C<:foo>)

=item * @NAME (named, e.g. C<@foo>)

=back

The module places little if any addtional cognitive burden upon developers
who continue to use C<prepare>, C<do>, C<execute> methods as they would 
normally.

The module's standard behaviour is to render unnecessary the manual binding
of parameters because, for any scheme other than positional C<?> placeholders,
that binding is done automatically. And it isn't usually necessary to manually
bind parameters when using postional placeholders.

When presenting parameter bindings to the C<do> and C<execute> methods, just 
remember to lay them out sensibly:

=over 2

=item Positional or numeric schemes

Parameter bindings may be presented as a simple list of parameters, as a
single reference to a list, or as a single anonymous array reference.

=item Name-based schemes

Parameter bindings may be presented as a simple list of key-value pairs, as
a single reference to a list of key-value pairs, as a single anonymous array 
reference containing key-value pairs, or as a single anonymous hash 
reference.

=back
 
=head1 METHODS

=head2 function1

=head2 function2

=head1 EXPORTED SUBROUTINES

Nothing is exported.

=head1 AUTHOR

Iain Campbell, C<< <cpanic at cpan.org> >>

=head1 REPOSITORY

L<https://github.com/cpanic/DBIx-FlexibleBinding>

=head1 BUGS

Please report any bugs or feature requests to C<bug-dbix-anybinding at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBIx-FlexibleBinding>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DBIx::FlexibleBinding


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DBIx-FlexibleBinding>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DBIx-FlexibleBinding>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DBIx-FlexibleBinding>

=item * Search CPAN

L<http://search.cpan.org/dist/DBIx-FlexibleBinding/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2015 Iain Campbell.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2 dated June, 1991 or at your option
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

A copy of the GNU General Public License is available in the source tree;
if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA


=cut

