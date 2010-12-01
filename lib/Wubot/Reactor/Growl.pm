package Wubot::Reactor::Growl;
use Moose;

use POSIX qw(strftime);
use YAML;

my $growl_enabled = 1;
eval "use Growl::Tiny";
if ( $@ ) { $growl_enabled = 0 }


my %color_priorities = ( 'red'     => 2,
                         'yellow'  => 1,
                         'orange'  => 1,
                         'green'   => -1,
                         'grey'    => 0,
                         'magenta' => -2,
                         'blue'    => -2,
                         'cyan'    => -2,
                     );

sub react {
    my ( $self, $message, $config ) = @_;

    return unless $growl_enabled;
    return if $message->{quiet};
    return if $message->{quiet_growl};

    my $subject = $message->{subject_text} || $message->{subject};
    return unless $subject;

    my $color = $message->{color};

    my $sticky = $message->{sticky} ? 1 : 0;

    if ( $message->{urgent} ) {
        $sticky = 1;
        $color = 'red';
    }

    my $priority = 0;
    if ( $color ) {
        $priority = $color_priorities{ $color };
    }
    elsif ( $message->{priority} ) {
        $priority = $message->{priority};
    }
    elsif ( $message->{errmsg} ) {
        $priority = $color_priorities{red};
    }

    my $notification = { sticky   => $sticky,
                         priority => $priority,
                         subject  => $subject,
                         host     => 'localhost',
                         color    => $color,
                     };

    my $username = $message->{username} || "wubot";

    my $date = strftime( "%d/%H:%M", localtime( $message->{lastupdate}||time ) );

    my $title;
    if ( $message->{growl_title} ) {
        $title = $message->{growl_title};
    }
    else {
        $title = "$username";
        if ( $message->{key} ) {
            $title .= " [$message->{key}]";
        }
        $title .= " $date";
    }
    $notification->{title} = $title;

    my $image = $notification->{image} || "wubot.png";
    $image =~ s|^.*\/||;
    my $image_dir = $config->{image_dir} || "$ENV{HOME}/.icons";
    $image = join( "/", $image_dir, $image );
    $notification->{image} = $image;

    $notification->{results} = Growl::Tiny::notify( $notification );

    $message->{growl} = $notification;

    return $message;
}

1;
