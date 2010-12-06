package Wubot::Reactor::ImageStrip;
use Moose;

use HTML::Strip;
use YAML;

sub react {
    my ( $self, $message, $config ) = @_;

    my $field    = $config->{field};
    my $newfield = $config->{newfield} || $field;

    my $value = $message->{ $field };

    if ( $value ) {

        $value =~ s|\<img[^\>]+\>||sg;
        $value =~ s|\</img\>||sg;

        $value =~ s|<iframe.*</iframe>||s;

        $message->{$newfield} = $value;
    }

    return $message;
}

1;
