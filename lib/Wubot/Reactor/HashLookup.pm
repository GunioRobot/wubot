package Wubot::Reactor::HashLookup;
use Moose;

# VERSION

sub react {
    my ( $self, $message, $config ) = @_;

    my $key = $message->{ $config->{source_field} };

    return $message unless $key;

    if ( exists $config->{lookup}->{ $key } ) {
        $message->{ $config->{target_field} } = $config->{lookup}->{ $key };
    }

    return $message;
}

1;
