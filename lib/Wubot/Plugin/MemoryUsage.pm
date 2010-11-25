package Wubot::Plugin::MemoryUsage;
use Moose;

use Devel::Size;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $config ) = @_;

    for my $plugin ( keys %{ $main::plugin_objs } ) {
        my $size = Devel::Size::total_size( $main::plugin_objs->{$plugin}->{instance} );

        if ( $self->cache->{$plugin}->{size} ) {
            if ( $size > $self->cache->{$plugin}->{size} ) {
                $self->logger->warn( "memory increased for plugin $plugin: $self->{cache}->{$plugin}->{size} => $size" );
            }
        }

        $self->cache->{$plugin}->{size} = $size;
    }

    return 1;
}

1;
