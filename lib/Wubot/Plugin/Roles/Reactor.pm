package Wubot::Plugin::Roles::Reactor;
use Moose::Role;

has 'reactor'  => ( is       => 'ro',
                    isa      => 'Wubot::Reactor',
                    required => 1,
                );

sub react {
    my ( $self, $data ) = @_;

    return unless $data;

    # use our class name for the 'plugin' field
    $data->{plugin}     = $self->{class};

    # use our instance key name for the 'key' field
    $data->{key}        = $self->key;

    $self->reactor->react( $data );

    return $data;
}

1;
