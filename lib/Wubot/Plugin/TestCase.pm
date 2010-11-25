package Wubot::Plugin::TestCase;
use Moose;

with 'Wubot::Plugin::Roles::Plugin';
with 'Wubot::Plugin::Roles::Reactor';

sub check {
    my ( $self, $config, $cache ) = @_;

    # just setting the cache params in the config
    for my $key ( keys %{ $config } ) {
        $cache->{$key}   = $config->{$key};

        $self->react( { $key => $config->{$key} } );
    }

    return $cache;
}

1;
