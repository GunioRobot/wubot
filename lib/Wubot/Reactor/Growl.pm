package Wubot::Reactor::Growl;
use Moose;

use Growl::Tiny;

sub react {
    my ( $self, $message, $config ) = @_;

    if ( $message->{image} ) {
        my $image = $message->{image};
        $image =~ s|^.*\/||;
        $image = join( "/", $config->{image_dir}, $image );
        $message->{image} = $image;
    }

    Growl::Tiny::notify( $message );

}

1;
