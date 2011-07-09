package Wubot::Reactor::Growl;
use Moose;

# VERSION

use POSIX qw(strftime);
use YAML;

my $growl_enabled = 1;
eval "use Growl::Tiny";  ## no critic (ProhibitStringyEval)
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

    my $date;

    if ( $message->{lastupdate} ) {
        if ( time - $message->{lastupdate} > 86400 ) {
            $date = strftime( "%d/%H:%M", localtime( $message->{lastupdate} ) );
        }
        else {
            $date = strftime( "%H:%M", localtime( $message->{lastupdate} ) );
        }
    }
    else {
        $date = strftime( "%H:%M", localtime( $message->{lastupdate} ) );
    }

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

    my $image_dir = $config->{image_dir} || "$ENV{HOME}/.icons";

    my @possible_images;
    if ( $message->{image}    ) { push @possible_images, $message->{image} }
    if ( $message->{username} && $message->{username} ne "wubot" ) {
        push @possible_images, "$message->{username}.png";

        if ( $message->{username} =~ m|\@| ) {
            $message->{username} =~ m|^(.*)\@|;
            my $username = $1;
            $username =~ s|^.*\<||;
            push @possible_images, "$username.png";
        }
        if ( $message->{username} =~ m/\|/ ) {
            $message->{username} =~ m/^(.*)\|/;
            my $username = $1;
            push @possible_images, "$username.png";
        }
    }
    if ( $message->{key} ) {
        push @possible_images, "$message->{key}.png";
        my $service = $message->{key};
        $service =~ s|^.*?\-||;
        push @possible_images, "$service.png";
    }
    push @possible_images, "wubot.png";

  IMAGE:
    for my $image ( @possible_images ) {

        $image = lc( $image );
        $image =~ s|^.*\/||;
        $image = join( "/", $image_dir, $image );

        next IMAGE unless -r $image;

        $notification->{image} = $image;
        last IMAGE;
    }

    if ( $message->{growl_id} ) {
        $notification->{identifier} = $message->{growl_id};
    }
    else {
        my $id = $message->{key} || $subject;

        $notification->{identifier} = join( ":", $id, $sticky );;
    }

    $notification->{results} = Growl::Tiny::notify( $notification );

    $message->{growl} = $notification;

    return $message;
}

1;
