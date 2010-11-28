package Wubot::Plugin::MemoryUsage;
use Moose;

use Devel::Size;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $cache = $inputs->{cache};

    for my $plugin ( keys %{ $main::plugin_objs } ) {
        my $size = Devel::Size::total_size( $main::plugin_objs->{$plugin}->{instance} );

        if ( $cache->{$plugin}->{size} ) {
            if ( $size > $cache->{$plugin}->{size} ) {
                $self->logger->warn( "memory increased for plugin $plugin: $cache->{$plugin}->{size} => $size" );
            }
        }

        $cache->{$plugin}->{size} = $size;
    }

    return { cache => $cache };
}

1;
