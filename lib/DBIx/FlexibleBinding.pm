package DBIx::FlexibleBinding;

=head1 NAME

DBIx::FlexibleBinding - flexible parameter binding and record fetching

=head1 SYNOPSIS

    # Introducing the module...
    # 
    use DBIx::FlexibleBinding;
    my $dbh = DBIx::FlexibleBinding->connect($dsn, $user, $pass, \%attributes);

    
    # Or, alteratively...
    # 
    use DBI;
    my $dbh = DBI->connect($dsn, $user, $pass, { %attributes, RootClass => 'DBIx::FlexibleBinding' }); 
    
    
    # Using the "do" method...
    # 
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
    
    
    # Prepare using :NAME scheme...
    # 
    my $sth = $dbh->prepare(<< 'EOF');
    SELECT * 
      FROM cakes 
     WHERE type    = :type    
       AND colour  = :colour  
       AND flavour = :flavour
    EOF
    
    
    # Execute (any of the are valid for this named scheme)...
    # 
    my $row_count = $sth->execute(type => 'sponge', colour => 'yellow', flavour => 'yummy');
    my $row_count = $sth->execute([ type => 'sponge', colour => 'yellow', flavour => 'yummy' ]);
    my $row_count = $sth->execute({ type => 'sponge', colour => 'yellow', flavour => 'yummy' });

    
    # Prepare using @NAME scheme...
    # 
    my $sth = $dbh->prepare(<< 'EOF');
    SELECT * 
      FROM cakes 
     WHERE type    = @type    
       AND colour  = @colour  
       AND flavour = @flavour
    EOF
    
    
    # Execute (any of the are valid for this named scheme)...
    # 
    my $row_count = $sth->execute('@type' => 'sponge', '@colour' => 'yellow', '@flavour' => 'yummy');
    my $row_count = $sth->execute([ '@type' => 'sponge', '@colour' => 'yellow', '@flavour' => 'yummy' ]);
    my $row_count = $sth->execute({ '@type' => 'sponge', '@colour' => 'yellow', '@flavour' => 'yummy' });

    
    # Prepare using :N scheme...
    # 
    my $sth = $dbh->prepare(<< 'EOF');
    SELECT * 
      FROM cakes 
     WHERE type    = :1    
       AND colour  = :2  
       AND flavour = :3
    EOF
    
    
    # Execute (any of the are valid for this numeric scheme)...
    # 
    my $row_count = $sth->execute('sponge', 'yellow', 'yummy');
    my $row_count = $sth->execute([ 'sponge', 'yellow', 'yummy' ]);

    
    # Prepare using ?N scheme...
    # 
    my $sth = $dbh->prepare(<< 'EOF');
    SELECT * 
      FROM cakes 
     WHERE type    = ?1    
       AND colour  = ?2  
       AND flavour = ?3
    EOF
    
    
    # Execute (any of the are valid for this numeric scheme)...
    # 
    my $row_count = $sth->execute('sponge', 'yellow', 'yummy');
    my $row_count = $sth->execute([ 'sponge', 'yellow', 'yummy' ]);

    
    # Prepare using ? scheme...
    # 
    my $sth = $dbh->prepare(<< 'EOF');
    SELECT * 
      FROM cakes 
     WHERE type    = ?    
       AND colour  = ?  
       AND flavour = ?
    EOF
    
    
    # Execute (any of the are valid for this positional scheme)...
    # 
    my $row_count = $sth->execute('sponge', 'yellow', 'yummy');
    my $row_count = $sth->execute([ 'sponge', 'yellow', 'yummy' ]);

    
    # Data binding is automatic by default.
    # 
    # Those with a penchant for masochism may switch automatic binding 
    # off completely using the C<auto_bind> method, or by changing the
    # value of DBIx::FlexibleBinding::DEFAULT_AUTO_BIND to 0.
    # 
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
    #
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
    
    
    # Fetching and processing a single row (arrayref)
    #
    my $sth = $dbh->prepare('SELECT COUNT(*) AS count FROM cakes');
    $sth->execute();
    
    my $arrayref = $sth->processrow_arrayref()          # extra, unnecessary state
    my $count = $arrayref->[0];                         # the value we actually wanted
    
    # Or ...
    #
    my $count = $sth->processrow_arrayref(callback {    # single piece of state and the value we wanted
        return $_->[0];                                 # use $_  and $_[0] to reference the row in a callback
    });                                                 # callback not called for emty result set
    
    
    # Fetching and processing a single row (hashref)
    #
    my $sth = $dbh->prepare('SELECT COUNT(*) AS count FROM cakes');
    $sth->execute();
    
    my $hashref = $sth->processrow_hashref()            # extra, unnecessary state
    my $count = $hashref->{count};                      # the value we actually wanted
    
    # Or ...
    #
    my $count = $sth->processrow_hashref(callback {     # single piece of state and the value we wanted
        return $_[0]{count};                            # use $_  and $_[0] to reference the row in a callback
    });                                                 # callback not called for emty result set
    
    
    # Another way to fetch and process a single row (arrayref)
    #
    my $arrayref = $dbh->processrow_arrayref('SELECT COUNT(*) AS count FROM cakes');
    my $count = $arrayref->[0];
    
    # Or ...
    #
    my $count = $dbh->processrow_arrayref('SELECT COUNT(*) AS count FROM cakes', callback {
        return $_->[0];
    });
    
    
    # Another way to fetch and process a single row (hashref)
    #
    my $hashref = $dbh->processrow_hashref('SELECT COUNT(*) AS count FROM cakes');
    my $count = $hashref->{count};
    
    # Or ...
    #
    my $count = $dbh->processrow_hashref('SELECT COUNT(*) AS count FROM cakes', callback {
        return $_[0]{count};
    });
    
    
    # Fetching and processing multiple result sets...
    #
    my $array_of_array_refs = $dbh->processall_arrayref($statement, \%opt_attr, @opt_bindings, @opt_callbacks);
    my @array_of_array_refs = $dbh->processall_arrayref($statement, \%opt_attr, @opt_bindings, @opt_callbacks);
    my $array_of_hash_refs = $dbh->processall_hashref($statement, \%opt_attr, @opt_bindings, @opt_callbacks);
    my @array_of_hash_refs = $dbh->processall_hashref($statement, \%opt_attr, @opt_bindings, @opt_callbacks);
    my $array_of_array_refs = $sth->processall_arrayref(@opt_callbacks);
    my @array_of_array_refs = $sth->processall_arrayref(@opt_callbacks);
    my $array_of_hash_refs = $sth->processall_hashref(@opt_callbacks);
    my @array_of_hash_refs = $sth->processall_hashref(@opt_callbacks);
    
    
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

=cut

use 5.006;
use strict;
use warnings;
use MRO::Compat 'c3';
use Exporter ();
use DBI      ();
use namespace::clean;
use Params::Callbacks 'callback';

our $VERSION           = '0.001001';
our @ISA               = ( 'DBI', 'Exporter' );
our %EXPORT_TAGS       = ( all => [qw(callback)] );
our @EXPORT_OK         = @{ $EXPORT_TAGS{all} };
our $DEFAULT_AUTO_BIND = 1;

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
        $sth->{private_auto_binding}              = $DBIx::FlexibleBinding::DEFAULT_AUTO_BIND;
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

sub processrow_arrayref
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    unless ( ref($sth) )
    {
        my $attr;
        $attr = shift(@bind_values)
          if ref( $bind_values[0] ) && ref( $bind_values[0] ) eq 'HASH';
        $sth = $dbh->prepare( $sth, $attr );
    }

    if ( $sth->auto_bind() )
    {
        $sth->bind(@bind_values);
        $sth->execute();
    }
    else
    {
        $sth->execute(@bind_values);
    }

    my $result;
    $result = $sth->fetchrow_arrayref()
      unless $sth->err;

    if ($result)
    {
        local $_;
        $result = $callbacks->smart_transform( $_ = [@$result] )
          unless ( $sth->err );
    }

    return $result;
}

sub processrow_hashref
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    unless ( ref($sth) )
    {
        my $attr;
        $attr = shift(@bind_values)
          if ref( $bind_values[0] ) && ref( $bind_values[0] ) eq 'HASH';
        $sth = $dbh->prepare( $sth, $attr );
    }

    if ( $sth->auto_bind() )
    {
        $sth->bind(@bind_values);
        $sth->execute();
    }
    else
    {
        $sth->execute(@bind_values);
    }

    my $result;
    $result = $sth->fetchrow_hashref()
      unless $sth->err;

    if ($result)
    {
        local $_;
        $result = $callbacks->smart_transform( $_ = {%$result} )
          unless ( $sth->err );
    }

    return $result;
}

sub processall_arrayref
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    unless ( ref($sth) )
    {
        my $attr;
        $attr = shift(@bind_values)
          if ref( $bind_values[0] ) && ref( $bind_values[0] ) eq 'HASH';
        $sth = $dbh->prepare( $sth, $attr );
    }

    if ( $sth->auto_bind() )
    {
        $sth->bind(@bind_values);
        $sth->execute();
    }
    else
    {
        $sth->execute(@bind_values);
    }

    my $result;
    $result = $sth->fetchall_arrayref()
      unless $sth->err;

    if ($result)
    {
        local $_;
        $result = [ map { $callbacks->transform($_) } @$result ]
          unless ( $sth->err );
    }

    return $result
      unless defined $result;
    return wantarray ? @$result : $result;
}

sub processall_hashref
{
    my ( $callbacks, $dbh, $sth, @bind_values ) = &callbacks;

    unless ( ref($sth) )
    {
        my $attr;
        $attr = shift(@bind_values)
          if ref( $bind_values[0] ) && ref( $bind_values[0] ) eq 'HASH';
        $sth = $dbh->prepare( $sth, $attr );
    }

    if ( $sth->auto_bind() )
    {
        $sth->bind(@bind_values);
        $sth->execute();
    }
    else
    {
        $sth->execute(@bind_values);
    }

    my $result;
    $result = $sth->fetchall_arrayref( {} )
      unless $sth->err;

    if ($result)
    {
        local $_;
        $result = [ map { $callbacks->transform($_) } @$result ]
          unless ( $sth->err );
    }

    return $result
      unless defined $result;
    return wantarray ? @$result : $result;
}

package    # Hide from PAUSE
  DBIx::FlexibleBinding::st;

BEGIN
{
    *_dbix_set_err = \&DBIx::FlexibleBinding::_dbix_set_err;
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

sub bind
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
        $sth->bind(@bind_values);
        $rows = $sth->SUPER::execute();
    }
    else
    {
        if ( @bind_values == 1 && ref( $bind_values[0] ) && reftype( $bind_values[0] ) eq 'ARRAY' )
        {
            $rows = $sth->SUPER::execute( @{ $bind_values[0] } );
        }
        else
        {
            $rows = $sth->SUPER::execute(@bind_values);
        }
    }

    return ( $rows == 0 ) ? '0E0' : $rows;
}

sub processrow_arrayref
{
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchrow_arrayref();

    if ($result)
    {
        local $_;
        $result = $callbacks->smart_transform( $_ = [@$result] )
          unless ( $sth->err );
    }

    return $result;
}

sub processrow_hashref
{
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchrow_hashref();

    if ($result)
    {
        local $_;
        $result = $callbacks->smart_transform( $_ = {%$result} )
          unless ( $sth->err );
    }

    return $result;
}

sub processall_arrayref
{
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchall_arrayref();

    if ($result)
    {
        local $_;
        $result = [ map { $callbacks->transform($_) } @$result ]
          unless ( $sth->err );
    }

    return $result
      unless defined $result;
    return wantarray ? @$result : $result;
}

sub processall_hashref
{
    my ( $callbacks, $sth ) = &callbacks;
    my $result = $sth->fetchall_arrayref( {} );

    if ($result)
    {
        local $_;
        $result = [ map { $callbacks->transform($_) } @$result ]
          unless ( $sth->err );
    }

    return $result
      unless defined $result;
    return wantarray ? @$result : $result;
}

1;

=head1 EXPORTED SUBROUTINES

=over 2

=item B<callback>

A simple piece of syntactic sugar that announces a callback. The code
reference it precedes is blessed as a C<Params::Callbacks::Callback>
object, disambiguating it from unblessed subs that are being passed as 
standard arguments.

Multiple callbacks may be chained together with or without comma 
separators: 

    callback { ... }, callback { ... }, callback { ... }    # Valid
    callback { ... }  callback { ... }  callback { ... }    # Valid, too!
    
=back

=cut

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

