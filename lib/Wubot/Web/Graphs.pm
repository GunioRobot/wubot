package Wubot::Web::Graphs;
use strict;
use warnings;

# VERSION

use Mojo::Base 'Mojolicious::Controller';

use YAML;

my $config_file = join( "/", $ENV{HOME}, "wubot", "config", "webui.yaml" );

my $graphs = YAML::LoadFile( $config_file )->{graphs};

sub graphs {
    my $self = shift;

    my $search_key = $self->param( 'key' ) || "sensors";

    my @nav;
    my @png;
    for my $graph ( @{ $graphs } ) {
        my ( $key ) = keys %{ $graph };
        push @nav, $key;

        if ( $search_key && $search_key eq $key ) {
            for my $png ( @{ $graph->{$key} } ) {
                push @png, $png;
            }
        }
    }

    $self->stash( 'nav', \@nav );
    $self->stash( 'images', \@png );

    $self->render( template => 'graphs' );

};

1;

__END__

=head1 NAME

Wubot::Util::Graphs - web interface for wubot graphs

=head1 DESCRIPTION

The wubot web interface is still under construction.  There will be
more information here in the future.

TODO: finish docs
