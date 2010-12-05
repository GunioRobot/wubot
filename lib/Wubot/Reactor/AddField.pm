package Wubot::Reactor::AddField;
use Moose;

sub react {
    my ( $self, $message, $config ) = @_;

    $message->{ $config->{field} } = $config->{value};

    return $message;
}

1;
