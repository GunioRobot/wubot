package Wubot::Reactor::Growl;
use Moose;

use POSIX qw(strftime);
use YAML;

my $growl_enabled = 1;
eval "use Growl::Tiny";
if ( $@ ) { $growl_enabled = 0 }

sub react {
    my ( $self, $message, $config ) = @_;

    return $message unless $growl_enabled;
    return $message if $message->{quiet};
    return $message if $message->{quiet_growl};

    my $subject = $message->{subject_text} || $message->{subject};
    return $message unless $subject;

    my $sticky = $message->{sticky} ? 1 : 0;

    my $priority = $message->{growl_priority} || $message->{priority};

    my $notification = { sticky   => $sticky,
                         priority => $priority,
                         subject  => $subject,
                         host     => 'localhost',
                     };

    my $date = strftime( "%d/%H:%M", localtime( $message->{lastupdate}||time ) );

    my $title;
    if ( $message->{growl_title} ) {
        $title = $message->{growl_title};
    }
    else {
        if ( $message->{username} ) {
            $title = "$message->{username} ";
        }
        if ( $message->{key} ) {
            $title .= "[$message->{key}]";
        }
        $title .= " $date";
    }
    $notification->{title} = $title;

    my $image = $notification->{image} || "wubot.png";
    $image =~ s|^.*\/||;
    my $image_dir = $config->{image_dir} || "$ENV{HOME}/.icons";
    $image = join( "/", $image_dir, $image );
    $notification->{image} = $image;

    if ( $message->{growl_id} ) {
        $notification->{identifier} = $message->{growl_id};
    }

    $notification->{results} = Growl::Tiny::notify( $notification );

    $message->{growl} = $notification;

    return $message;
}

1;
