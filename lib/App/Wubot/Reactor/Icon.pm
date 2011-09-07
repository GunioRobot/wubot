package App::Wubot::Reactor::Icon;
use Moose;

# VERSION

use YAML;

use App::Wubot::Logger;

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

    if ( $message->{image} ) {
        if ( my $icon = $self->_check_for_image( $image_dir, $message->{image}, $config, 'image' ) ) {
            $message->{icon} = $icon;
            return $message;
        }
    }

    if ( $message->{username} && $message->{username} ne "wubot" ) {
        if ( my $icon = $self->_check_for_image( $image_dir, $message->{username}, $config, 'username' ) ) {
            $message->{icon} = $icon;
            return $message;
        }
    }


    if ( $message->{key} ) {

        if ( my $icon = $self->_check_for_image( $image_dir, $message->{key}, $config, 'key' ) ) {
            $message->{icon} = $icon;
            return $message;
        }

        $message->{key} =~ m|^(.*?)\-(.*)$|;
        my ( $plugin, $instance ) = ( $1, $2 );

        if ( my $icon = $self->_check_for_image( $image_dir, $instance, $config, 'instance' ) ) {
            $message->{icon} = $icon;
            return $message;
        }

        if ( my $icon = $self->_check_for_image( $image_dir, $plugin, $config, 'plugin', ) ) {
            $message->{icon} = $icon;
            return $message;
        }
    }

    # last chance
    $message->{icon} = $self->_check_for_image( $image_dir, "wubot", $config, 'wubot' );
    return $message;
}

sub _check_for_image {
    my ( $self, $image_dir, $image, $config, $key ) = @_;

    if ( $config ) {
        if ( $config->{custom}->{$key} ) {
            if ( $config->{custom}->{$key}->{$image} ) {
                $image = $config->{custom}->{$key}->{$image};
                $self->logger->debug( "Image custom for $key: $image" );
            }
        }
    }

    unless ( $image =~ m/\.(png|jpg|gif)$/ ) {
        $image .= ".png";
    }

    $image = lc( $image );
    $image =~ s|^.*\/||;

    $self->logger->trace( "Looking for icon: $image" );

    $image = join( "/", $image_dir, $image );

    return unless -r $image;

    $self->logger->debug( "Found image: $image" );

    return $image;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

App::Wubot::Reactor::Icon - search for an appropriate icon for a message


=head1 SYNOPSIS

      - name: icon
        plugin: Icon
        config:
          image_dir: /Users/your_id/.icons


=head1 DESCRIPTION

Attempts to find a suitable image for a message by looking for a file
in the icon directory that matches a field on the message:

  - 'image' field

  - 'username' field

  - monitor key

  - monitor plugin name

  - monitor instance name

If no suitable icon can be found, then the image field will be set to
'wubot.png'.

Note that the Icon plugin no longer tries to parse any information in
the username field.  It is highly recommended that you use the User
reactor plugin prior to using the Icon plugin so that the username
field is parsed appropriately.

For more information, please see the 'notifications' document.

=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back
