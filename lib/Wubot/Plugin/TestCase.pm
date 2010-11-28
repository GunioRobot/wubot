package Wubot::Plugin::TestCase;
use Moose;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';
with 'Wubot::Plugin::Roles::Reactor';

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    # just setting the cache params in the config
    for my $key ( keys %{ $config } ) {

        $cache->{$key}   = $config->{$key};

        $self->react( { $key => $config->{$key} } );
    }

    return { cache => $cache };
}

1;
