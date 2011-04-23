package Wubot::Reactor::CopyField;
use Moose;

# VERSION

use HTML::Strip;
use YAML;

sub react {
    my ( $self, $message, $config ) = @_;

    $message->{ $config->{target_field} } = $message->{ $config->{source_field } };

    return $message;
}

1;
