package App::Wubot::Reactor::ImageStrip;
use Moose;

# VERSION

use YAML;

use App::Wubot::Logger;

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

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

App::Wubot::Reactor::ImageStrip - strip image tags from a field

=head1 SYNOPSIS

  - name: strip images from 'body' field and store results in the field body_text
    plugin: ImageStrip
    config:
      field: body

  - name: strip images from the body field in-situ
    plugin: ImageStrip
    config:
      field: body
      newfield: body


=head1 DESCRIPTION

The ImageStrip plugin attempts to remove any img or iframe tags from a
message field.  The original field content is not overwritten by
default.  If you do not specify a 'newfield', then the image-stripped
content will be stored in a new field that matches the original field
but ends in _text.  If you specify a 'newfield' in the config, then
the image-stripped text will be stored in that field.  If you want to
replace the contents of an existing field with the image-stripped
content, then use the same field for both 'field' and 'newfield'.

=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back
