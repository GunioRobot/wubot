package Wubot::Util::Colors;
use Moose;

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
