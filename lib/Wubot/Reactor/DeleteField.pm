package Wubot::Reactor::DeleteField;
use Moose;

sub react {
    my ( $self, $message, $config ) = @_;

    delete $message->{ $config->{field} };

    return $message;
}

1;
