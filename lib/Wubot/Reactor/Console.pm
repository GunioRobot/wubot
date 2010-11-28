package Wubot::Reactor::Console;
use Moose;

use POSIX qw(strftime);
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

    return unless $message->{subject};
    return if $message->{quiet};
    return if $message->{quiet_console};

    my $subject = $message->{subject};

    if ( $message->{title} && $message->{title} ne $message->{subject} ) {
        my $title   = $message->{title};
        $subject = "$title => $subject";
    }

    if ( $message->{key} ) {
        $subject = "[$message->{key}] $subject";
    }

    my $date = strftime( "%Y/%m/%d %H:%M:%S", localtime( $message->{lastupdate} || time ) );
    $subject = "$date> $subject";

    my $color = 'white';
    if ( $message->{color} && $valid_colors->{ $message->{color} } ) {
        $color = $valid_colors->{ $message->{color} };
    }

    if ( $message->{urgent} && $color !~ m/bold/ ) {
        $color = "bold $color";
    }

    $message->{console}->{color} = $color;
    print color $color;

    $message->{console}->{text}  = $subject;
    print $subject;

    print color 'reset';
    print "\n";

    return $message;
}

1;
