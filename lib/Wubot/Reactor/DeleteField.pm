package Wubot::Reactor::DeleteField;
use Moose;

# VERSION

sub react {
    my ( $self, $message, $config ) = @_;

    delete $message->{ $config->{field} };

    return $message;
}

1;
