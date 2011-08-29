package Wubot::Reactor::User;
use Moose;

# VERSION

use YAML;

use Wubot::Logger;

has 'userdb'  => ( is => 'ro',
                   isa => 'HashRef',
                   lazy => 1,
                   default => sub {
                       my $self = shift;
                       $self->read_user_info();
                   },
               );

has 'directory' => ( is => 'ro',
                     isa => 'Str',
                     lazy => 1,
                     default => sub {
                         return join( "/", $ENV{HOME}, "wubot", "userdb" );
                     },
                 );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub react {
    my ( $self, $message, $config ) = @_;

    return $message unless $message->{username};

    unless ( $message->{username_orig} ) {
        $message->{username_orig} = $message->{username};
    }

    if ( $message->{username} =~ m|\@| ) {
        $message->{username} =~ m|^(.*)\@(.*)|;

        $message->{username} = $1;

        $message->{username_domain} = $2;
        $message->{username_domain} =~ s|\>$||;

        if ( $message->{username} =~ m|^(.*)\s?\<(.*)$| ) {

            $message->{username_full} = $1;
            $message->{username} = $2;

            $message->{username_full} =~ s|^\s+||;
            $message->{username_full} =~ s|\s$||;

            $message->{username_full} =~ s|^\"||;
            $message->{username_full} =~ s|\"$||;
        }
    }

    if ( $message->{username} =~ m/\|/ ) {
        $message->{username} =~ m/^(.*)\|(.*)$/;
        $message->{username} = $1;
        $message->{username_comment} = $2;
    }

    if ( $message->{username} =~ m/\{.*\}/ ) {
        $message->{username} =~ m/^(.*)\{(.*)\}/;
        $message->{username} = $1;
        $message->{username_comment} = $2;
    }

    if ( $self->userdb->{ $message->{username} } ) {

        for my $param ( qw( username color image ) ) {

            if (    $message->{$param}
                 && ! $message->{"$param\_orig"}
                 && $message->{$param} ne $self->userdb->{ $message->{username} }->{ $param } ) {
                $message->{"$param\_orig"} = $message->{$param};
            }
            if ( $self->userdb->{ $message->{username} }->{ $param } ) {
                $self->logger->trace( "Setting $param for $message->{username}" );
                $message->{$param} = $self->userdb->{ $message->{username} }->{ $param };
            }
        }
    }

    return $message;
}

sub read_user_info {
    my ( $self ) = @_;

    my $config = {};

    my $directory = $self->directory;

    my $dir_h;
    opendir( $dir_h, $directory ) or die "Can't opendir $directory: $!";
    while ( defined( my $entry = readdir( $dir_h ) ) ) {
        next unless $entry;

        my $path = join( "/", $directory, $entry );
        next unless -f $path;

        my $user = $entry;
        $user =~ s|.yaml$||g;

        my $user_info = YAML::LoadFile( $path );
        $user_info->{username} = $user;

        $config->{$user} = $user_info;

        if ( $config->{$user}->{aliases} ) {
            for my $alias ( keys %{ $config->{$user}->{aliases} } ) {

                $config->{$alias} = $user_info;
            }
        }
    }
    closedir( $dir_h );

    return $config;
}

1;


__END__


=head1 NAME

Wubot::Reactor::User - try to identify user from the 'username' field


=head1 SYNOPSIS

      - name: user
        plugin: User

=head1 DESCRIPTION

The user reactor will parse the username field.

The original user id will always be preserved in the username_orig
field.  If the username_orig field already exists, it will not be
overwritten.

If the username field contains an email address (e.g. the from on an
mbox monitor message), then the domain will be captured into the
username_domain field.  If the email contains a full name it will be
captured into username_full.  Any leading or trailing quotes or spaces
will be removed from the full username field.

Commonly usernames in IRC may contain some comment such as
username|idle or username{idle}.  Any such comments will be extracted
into the username_comment field.

Any remaining text will be left in the username field.

After this plugin has reacted on the message, you may want to send it
through the Icon reactor to determine if there is an appropriate icon
for the user in your images directory.  For more information, please
see the 'notifications' document.

Eventually this plugin will be adapted to identify a user in a
database of contacts, and optionally apply configuration data from the
contact db, e.g. a nickname or a username_color.

=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back
