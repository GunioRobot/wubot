package App::Wubot::Reactor::HTMLStrip;
use Moose;

# VERSION

use HTML::Strip;
use YAML;

use App::Wubot::Logger;

sub react {
    my ( $self, $message, $config ) = @_;

    my $field    = $config->{field};
    my $newfield = $config->{target_field} || $config->{newfield} || join( '_', $config->{field}, 'text' );

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

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

App::Wubot::Reactor::HTMLStrip - strip HTML data from a field

=head1 SYNOPSIS

  - name: strip HTML from 'title' field and store results in the field title_text
    plugin: HTMLStrip
    config:
      field: title

  - name: strip HTML from the title field in-situ
    plugin: HTMLStrip
    config:
      field: title
      target_field: title


=head1 DESCRIPTION

The HTMLStrip plugin uses the perl module HTML::Strip to remove HTML
from a field.  The original field content is not overwritten by
default.  If you do not specify a 'target_field', then the
HTML-stripped content will be stored in a newly created field that
hast the same name as the original field plus _text.  For example, if
you use the 'subject' field, the results will go into 'subject_text'
by default.  If you specify a 'target_field' in the config, then the
HTML-stripped text will be stored in that field.  If you want to
replace the contents of an existing field with the HTML-stripped
content, set 'field' and 'target_field' to the same field.

HTML::Strip can leave many \xA0 characters in the text which can be
difficult to deal with.  So HTMLStrip replaces all such characters
with a single whitespace.

If the new field is utf8 (according to utf8::is_utf8), then the new
field will be passed to utf8::encode().

=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back
