package Wubot::Plugin::FileRegexp;
use Moose;

use Log::Log4perl;

use Wubot::Tail;

has 'path'      => ( is      => 'rw',
                     isa     => 'Str',
                     default => '',
                 );

has 'tail'      => ( is      => 'ro',
                     isa     => 'Wubot::Tail',
                     lazy    => 1,
                     default => sub {
                         my ( $self ) = @_;
                         return Wubot::Tail->new( { path  => $self->path } );
                     },
                 );

has 'logger'    => ( is      => 'ro',
                     isa     => 'Log::Log4perl::Logger',
                     lazy    => 1,
                     default => sub {
                         return Log::Log4perl::get_logger( __PACKAGE__ );
                     },
                 );

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub init {
    my ( $self, $inputs ) = @_;

    #$self->{react} = $inputs->{cache};
    #delete $self->{react}->{lastupdate};

    $self->path( $inputs->{config}->{path} );

    my $callback = sub {
        my $line = shift;
        for my $regexp_name ( keys %{ $inputs->{config}->{regexp} } ) {

            my $regexp = $inputs->{config}->{regexp}->{ $regexp_name };

            if ( $line =~ m|$regexp| ) {
                $self->{react}->{ $regexp_name }++;
            }
        }
    };

    $self->tail->callback( $callback );

    $self->tail->reset_callback( sub { print YAML::Dump @_ } );

    if ( $inputs->{cache}->{position} ) {
        $self->tail->position( $inputs->{cache}->{position} );
    }

    return;
}

sub check {
    my ( $self, $inputs ) = @_;

    $self->{react} = {};

    $self->tail->get_lines();

    if ( $self->{react} ) {
        return { react => { %{ $self->{react} } },
                 cache => { position => $self->tail->position },
             };
    }

    return { cache => { position => $self->tail->position } };
}

1;
