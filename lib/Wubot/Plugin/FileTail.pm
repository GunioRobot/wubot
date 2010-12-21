package Wubot::Plugin::FileTail;
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
                         return Wubot::Tail->new( { path           => $self->path,
                                                } );
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

    $self->path( $inputs->{config}->{path} );

    my $callback = sub { push @{ $self->{react} }, { subject => $_[0] } };

    $self->tail->callback(       $callback );
    $self->tail->reset_callback( $callback );

    return;
}

sub check {
    my ( $self, $inputs ) = @_;

    $self->tail->get_lines();

    if ( $self->{react} ) {
        my $return = { react => \@{ $self->{react} } };
        undef $self->{react};
        return $return;
    }

    return;
}

1;
