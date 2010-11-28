package Wubot::Plugin::Roles::Reactor;
use Moose::Role;

has 'reactor'  => ( is       => 'ro',
                    isa      => 'Wubot::Reactor',
                    required => 1,
                );

sub react {
    my ( $self, $react_h ) = @_;

    return unless $react_h;

    my @results;
    if ( ref $react_h eq "ARRAY" ) {
        @results = @{ $react_h };
    }
    else {
        push @results, $react_h;

    }

    for my $result ( @results ) {
        # use our class name for the 'plugin' field
        $result->{plugin}     = $self->{class};
        # use our instance key name for the 'key' field
        $result->{key}        = $self->key;

        $self->reactor->react( $result );
    }

    return $react_h;
}

1;
