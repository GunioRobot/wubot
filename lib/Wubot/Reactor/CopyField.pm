package Wubot::Reactor::CopyField;
use Moose;

use HTML::Strip;
use YAML;

sub react {
    my ( $self, $message, $config ) = @_;

    $message->{ $config->{target_field} } = $message->{ $config->{source_field } };

    print YAML::Dump $message;

    return $message;
}

1;
