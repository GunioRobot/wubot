package Wubot::Reactor::False;
use Moose;

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

    unless ( $message->{ $config->{field} } ) {

        $self->logger->debug( "matched => $config->{field} is false" );

        for my $key ( keys %{ $config->{set} } ) {

            $self->logger->info( "setting field $key to $config->{set}->{$key}" );
            $message->{ $key } = $config->{set}->{$key};

        }
    }

    return $message;
}

1;
