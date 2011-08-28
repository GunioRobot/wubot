package Wubot::Web::Graphs;
use strict;
use warnings;

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
