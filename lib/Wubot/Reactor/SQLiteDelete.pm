package Wubot::Reactor::SQLiteDelete;
use Moose;

# VERSION

use YAML;

use Wubot::Logger;
use Wubot::SQLite;

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
        $self->sqlite->{ $config->{file} } = Wubot::SQLite->new( { file => $config->{file} } );
    }

    my $field = $config->{where_field};

    $self->sqlite->{ $config->{file} }->delete( $config->{tablename}, { $field => $message->{$field} } );

    return $message;
}

1;
