package Wubot::Reactor::Dumper;
use Moose;

# VERSION

use YAML;

sub react {
    my ( $self, $message, $config ) = @_;

    print YAML::Dump $message;

    return $message;
}

1;
