package Wubot::Util::Colors;
use Moose;

# VERSION

# solarized color schema: http://ethanschoonover.com/solarized
my $pretty_colors = { pink      => '#FF33FF',
                      yellow    => '#b58900',
                      orange    => '#cb4b16',
                      red       => '#dc322f',
                      magenta   => '#770077',
                      brmagenta => '#d33682',
                      violet    => '#6c71c4',
                      blue      => '#268bd2',
                      cyan      => '#2aa198',
                      green     => '#859900',
                      black     => '#333333',
                      brblack   => '#002b36',
                      brgreen   => '#586e75',
                      bryellow  => '#657b83',
                      brblue    => '#839496',
                      brcyan    => '#93a1a1',
                      white     => '#eee8d5',
                      brwhite   => '#fdf6e3',
                      purple    => 'magenta',
                      dark      => 'black',
                  };

# color aliases
for my $color ( sort keys %{ $pretty_colors } ) {
    my $value = $pretty_colors->{$color};
    if ( $pretty_colors->{ $value } ) {
        $pretty_colors->{$color} = $pretty_colors->{ $value };
    }
}

sub get_color {
    my ( $self, $color ) = @_;

    if ( $pretty_colors->{$color} ) {
        return $pretty_colors->{$color};
    }

    return $color;
}

1;

__END__

=head1 NAME

Wubot::Util::Colors - color themes for wubot

=head1 DESCRIPTION

This module defines color codes for named colors for the wubot web ui.

The web ui is still under development.  Current the colors are
hard-coded.  In the future these will be configurable.

TODO: finish docs

=head1 SUBROUTINES/METHODS

=over 8

=item $obj->get_color( $color_name )

if there is a hex code defined in the theme for the specified color
name, return that hex code.

If called with a hex color or a color name that is not defined in the
theme, just returns the text that was passed in.

=back


