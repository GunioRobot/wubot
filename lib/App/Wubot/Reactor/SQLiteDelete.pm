package App::Wubot::Reactor::SQLiteDelete;
use Moose;

# VERSION

use YAML;

use App::Wubot::Logger;
use App::Wubot::SQLite;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'sqlite'  => ( is => 'ro',
                   isa => 'HashRef',
                   default => sub { {} },
               );

sub react {
    my ( $self, $message, $config ) = @_;

    my $sqlite;

    # if we don't have a sqlite object for this file, create one now
    unless ( $self->sqlite->{ $config->{file} } ) {
        $self->sqlite->{ $config->{file} } = App::Wubot::SQLite->new( { file => $config->{file} } );
    }

    my $field = $config->{where_field};

    $self->sqlite->{ $config->{file} }->delete( $config->{tablename}, { $field => $message->{$field} } );

    return $message;
}

1;

__END__

=head1 NAME

App::Wubot::Reactor::SQLiteDelete - delete a row from a SQLite table

=head1 DESCRIPTION

TODO: More to come...


=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back
