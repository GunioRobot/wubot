package Wubot::Reactor::CaptureData;
use Moose;

use YAML;

sub react {
    my ( $self, $message, $config ) = @_;

    my $field_data = $message->{ $config->{source_field} };

    return $message unless $field_data;

    $field_data =~ m|$config->{regexp}|;

    $message->{ $config->{target_field} } = $1;

    return $message;
}

1;
