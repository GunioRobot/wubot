package Wubot::Plugin::MemoryUsage;
use Moose;

use Devel::Size;
use Log::Log4perl;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub check {
    my ( $self, $config, $cache ) = @_;

    for my $plugin ( keys %{ $main::plugin_objs } ) {
        my $size = Devel::Size::total_size( $main::plugin_objs->{$plugin}->{instance} );

        if ( $cache->{$plugin}->{size} ) {
            if ( $size > $cache->{$plugin}->{size} ) {
                $self->logger->warn( "memory increased for plugin $plugin: $cache->{$plugin}->{size} => $size" );
            }
        }

        $cache->{$plugin}->{size} = $size;
    }

    return $cache;
}

1;
