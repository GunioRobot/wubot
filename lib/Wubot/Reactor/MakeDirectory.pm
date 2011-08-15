package Wubot::Reactor::MakeDirectory;
use Moose;

# VERSION

use File::Path;

use Wubot::Logger;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub react {
    my ( $self, $message, $config ) = @_;

    unless ( $config->{field} ) {
        $self->logger->error( "ERROR: MakeDirectory: field not defined in config", YAML::Dump $config );
        return $message;
    }

    my $directory = $message->{ $config->{field} };

    unless ( $directory ) {
        $self->logger->error( "Could not create directory: $directory ( $config->{field} )" );
    }

    return $message if -d $directory;

    $self->logger->warn( "Creating directory: $directory" );

    eval {                          # try
        mkpath( $directory );
        1;
    } or do {                       # catch
        $self->logger->error( "Couldn't create directory: $directory: $@" );
    };

    return $message;
}

1;
