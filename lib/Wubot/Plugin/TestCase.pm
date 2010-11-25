package Wubot::Plugin::TestCase;
use Moose;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';
with 'Wubot::Plugin::Roles::Reactor';

sub check {
    my ( $self, $config ) = @_;

    # just setting the cache params in the config
    for my $key ( keys %{ $config } ) {
        $self->cache->{$key}   = $config->{$key};

        $self->react( { $key => $config->{$key} } );
    }

    return 1;
}

1;
