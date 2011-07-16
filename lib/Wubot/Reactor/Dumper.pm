package Wubot::Reactor::Dumper;
use Moose;

# VERSION

use Log::Log4perl;
use YAML;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );


sub react {
    my ( $self, $message, $config ) = @_;

    if ( $config->{field} ) {
        $self->logger->warn( $message->{ $config->{field} } );
    }
    else {
        print YAML::Dump $message;
    }

    return $message;
}

1;
