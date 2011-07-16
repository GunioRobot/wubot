package Wubot::Reactor::Icon;
use Moose;

# VERSION

use Log::Log4perl;
use YAML;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'icon_dir' => ( is => 'ro',
                    isa => 'Str',
                    lazy => 1,
                    default => sub {
                        return "$ENV{HOME}/.icons";
                    },
                );

sub react {
    my ( $self, $message, $config ) = @_;

    my $image_dir = $config->{image_dir} || $self->icon_dir;

    my @possible_images;

    if ( $message->{image} ) {
        if ( my $icon = $self->check_for_image( $image_dir, $message->{image} ) ) {
            $message->{icon} = $icon;
            return $message;
        }
    }

    if ( $message->{username} && $message->{username} ne "wubot" ) {
        if ( my $icon = $self->check_for_image( $image_dir, "$message->{username}.png" ) ) {
            $message->{icon} = $icon;
            return $message;
        }

        if ( $message->{username} =~ m|\@| ) {
            $message->{username} =~ m|^(.*)\@|;
            my $username = $1;
            $username =~ s|^.*\<||;

            if ( my $icon = $self->check_for_image( $image_dir, "$username.png" ) ) {
                $message->{icon} = $icon;
                return $message;
            }

        }

        if ( $message->{username} =~ m/\|/ ) {
            $message->{username} =~ m/^(.*)\|/;
            my $username = $1;

            if ( my $icon = $self->check_for_image( $image_dir, "$username.png" ) ) {
                $message->{icon} = $icon;
                return $message;
            }
        }
    }

    if ( $message->{key} ) {

        if ( my $icon = $self->check_for_image( $image_dir, "$message->{key}.png" ) ) {
            $message->{icon} = $icon;
            return $message;
        }

        $message->{key} =~ m|^(.*?)\-(.*)$|;
        my ( $plugin, $instance ) = ( $1, $2 );

        if ( my $icon = $self->check_for_image( $image_dir, "$plugin.png" ) ) {
            $message->{icon} = $icon;
            return $message;
        }

        if ( my $icon = $self->check_for_image( $image_dir, "$instance.png" ) ) {
            $message->{icon} = $icon;
            return $message;
        }
    }

    # last chance
    $message->{icon} = $self->check_for_image( $image_dir, "wubot.png" );
    return $message;
}

sub check_for_image {
    my ( $self, $image_dir, $image ) = @_;

    $image = lc( $image );
    $image =~ s|^.*\/||;

    $self->logger->trace( "looking for $image" );

    $image = join( "/", $image_dir, $image );

    return unless -r $image;

    return $image;
}

1;
