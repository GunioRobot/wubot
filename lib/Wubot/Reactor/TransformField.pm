package Wubot::Reactor::TransformField;
use Moose;

# VERSION

use HTML::Strip;
use YAML;

sub react {
    my ( $self, $message, $config ) = @_;

    my $text = $message->{ $config->{source_field } };

    my $regexp_search = $config->{regexp_search};
    return $message unless $regexp_search;

    my $regexp_replace = $config->{regexp_replace} || "";

    $text =~ s|$regexp_search|$regexp_replace|g;

    $message->{ $config->{target_field}||$config->{source_field} } = $text;

    return $message;
}

1;
