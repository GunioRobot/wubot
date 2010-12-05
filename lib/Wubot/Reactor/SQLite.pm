package Wubot::Reactor::SQLite;
use Moose;

use Log::Log4perl;
use YAML;

use Wubot::SQLite;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'file'    => ( is => 'rw',
                   isa => 'Str',
               );

has 'sqlite'  => ( is => 'ro',
                   isa => 'Wubot::SQLite',
                   lazy => 1,
                   default => sub {
                       my ( $self ) = @_;
                       return Wubot::SQLite->new( { file => $self->file } );
                   },
               );

sub react {
    my ( $self, $message, $config ) = @_;

    if ( $config->{file} ) {
        $self->file( $config->{file} );
    }

    $self->sqlite->insert( $config->{tablename}, $message, $config->{schema} );

    return $message;
}

1;
