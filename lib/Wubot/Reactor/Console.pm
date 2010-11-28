package Wubot::Reactor::Console;
use Moose;

use Term::ANSIColor;

my $valid_colors = { blue    => 'blue',
                     cyan    => 'cyan',
                     red     => 'red',
                     white   => 'white',
                     green   => 'green',
                     orange  => 'yellow',
                     yellow  => 'bold yellow',
                     purple  => 'magenta',
                     magenta => 'magenta',
                 };

sub react {
    my ( $self, $message, $config ) = @_;

    my $color = 'white';
    if ( $message->{color} && $valid_colors->{ $message->{color} } ) {
        $color = $valid_colors->{ $message->{color} };
    }

    my $subject = $message->{subject};
    utf8::encode( $subject );

    if ( $message->{urgent} && $color !~ m/bold/ ) {
        print color "bold $color";
    } else {
        print color $color;
    }

    if ( $message->{title} ) {
        my $title   = $message->{title};
        utf8::encode( $title );

        print "> $title => $subject\n";
    }
    else {
        print "> $subject\n";

    }

    print color 'reset';

}

1;
