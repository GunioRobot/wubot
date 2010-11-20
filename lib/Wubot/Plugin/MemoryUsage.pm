package Wubot::Plugin::MemoryUsage;
use Moose;

use Devel::Size;

sub check {
    my ( $self, $config, $cache ) = @_;

    my $results = [];

    for my $plugin ( keys %{ $main::plugin_objs } ) {
        my $size = Devel::Size::total_size( $main::plugin_objs->{$plugin} );

        if ( $cache->{$plugin}->{size} ) {
            if ( $size > $cache->{$plugin}->{size} ) {
                print "Memory: increased for plugin $plugin: $cache->{$plugin}->{size} => $size\n";
            }
        }

        $cache->{$plugin}->{size} = $size;
    }

    return ( $results, $cache );
}

1;
