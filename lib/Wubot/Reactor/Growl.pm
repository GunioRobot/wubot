package Wubot::Reactor::Growl;
use Moose;

use Growl::Tiny;

my $image_dir = join( "/", $ENV{HOME}, ".icons" );

sub react {
    my ( $self, $message, $config ) = @_;

    if ( $message->{image} ) {
        my $image = $message->{image};
        $image =~ s|^.*\/||;
        $image = join( "/", $image_dir, $image );
        $message->{image} = $image;
    }

    Growl::Tiny::notify( $message );

}

1;
