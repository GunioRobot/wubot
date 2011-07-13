package Wubot::Reactor::SetField;
use Moose;

# VERSION

use Log::Log4perl;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub react {
    my ( $self, $message, $config ) = @_;

    if ( $config->{no_override} ) {
        return $message if $message->{ $config->{field} };
    }

    unless ( $config->{field} ) {
        $self->logger->warn( "ERROR: No field in SetField config: ", YAML::Dump $config );
        return $message;
    }

    $message->{ $config->{field} } = $config->{value};

    return $message;
}

1;
