package Wubot::Plugin::TestCase;
use Moose;

sub check {
    my ( $self, $config, $cache ) = @_;

    my $results = [];

    # just setting the cache params in the config
    for my $key ( keys %{ $config } ) {
        $cache->{$key}   = $config->{$key};

        push @{ $results }, { $key => $config->{$key} };
    }

    return ( $results, $cache );
}

1;
