package Wubot::Reactor::HTMLStrip;
use Moose;

# VERSION

use HTML::Strip;
use YAML;

sub react {
    my ( $self, $message, $config ) = @_;

    my $field    = $config->{field};
    my $newfield = $config->{newfield} || join( '_', $config->{field}, 'text' );

    my $value = $message->{ $field };

    if ( $value ) {

        my $hs = HTML::Strip->new();

        $message->{$newfield} = $hs->parse( $message->{$field} );

        $message->{$newfield} =~ s|\xA0| |g;

        if ( utf8::is_utf8( $message->{$newfield} ) ) {
            utf8::encode( $message->{$newfield} );
        }

        $hs->eof;

    }

    return $message;
}

1;

__END__


=head1 NAME

Wubot::Reactor::HTMLStrip - strip HTML data from a field

=head1 SYNOPSIS

  - name: strip HTML from 'title' field and store results in the field title_text
    plugin: HTMLStrip
    config:
      field: title

  - name: strip HTML from the title field in-situ
    plugin: HTMLStrip
    config:
      field: title
      newfield: title


=head1 DESCRIPTION

The HTMLStrip plugin uses the perl module HTML::Strip to remove HTML
from a field.  The original field content is not overwritten by
default.  If you do not specify a 'newfield', then the HTML-stripped
content will be stored in a new field that matches the original field
but ends in _text.  If you specify a 'newfield' in the config, then
the HTML-stripped text will be stored in that field.  If you want to
replace the contents of an existing field with the HTML-stripped
content, then use the same field for both 'field' and 'newfield'.

HTML::Strip can leave many \xA0 characters in the text which can be
difficult to deal with.  So HTMLStrip replaces all such characters
with a single whitespace.

If the new field is utf8 (according to utf8::is_utf8), then the new
field will be passed to utf8::encode().

