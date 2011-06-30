package Wubot::Reactor::CaptureData;
use Moose;

# VERSION

# todo: enable using Regexp::Common regexps here

use YAML;

sub react {
    my ( $self, $message, $config ) = @_;

    my $field_data = $message->{ $config->{source_field} };

    return $message unless $field_data;

    my $regexp;
    if ( $config->{regexp_field} ) {
        $regexp = $message->{ $config->{regexp_field} };
    }
    elsif ( $config->{regexp} ) {
        $regexp = $config->{regexp};
    }

    $field_data =~ m|$regexp|;

    my $target_field = $config->{target_field} || $config->{source_field};

    $message->{ $target_field } = $1;

    return $message;
}

1;
