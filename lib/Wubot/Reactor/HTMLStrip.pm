package Wubot::Reactor::HTMLStrip;
use Moose;

use HTML::Strip;
use YAML;

sub react {
    my ( $self, $message, $config ) = @_;

    my $field = $config->{field};
    my $newfield = join( '_', $config->{field}, 'text' );

    my $value = $message->{ $field };

    if ( $value ) {

        my $hs = HTML::Strip->new();

        $message->{$newfield} = $hs->parse( $message->{$field} );

        if ( utf8::is_utf8( $message->{$newfield} ) ) {
            utf8::encode( $message->{$newfield} );
        }

        $hs->eof;

    }

    return $message;
}

1;
