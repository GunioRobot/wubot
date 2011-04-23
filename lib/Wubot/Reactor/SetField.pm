package Wubot::Reactor::SetField;
use Moose;

# VERSION

sub react {
    my ( $self, $message, $config ) = @_;

    if ( $config->{no_override} ) {
        return $message if $message->{ $config->{field} };
    }

    $message->{ $config->{field} } = $config->{value};

    return $message;
}

1;
