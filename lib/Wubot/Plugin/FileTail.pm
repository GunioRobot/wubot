package Wubot::Plugin::FileTail;
use Moose;

# VERSION

use Wubot::Logger;
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

    my $ignore;
    if ( $inputs->{config}->{ignore} ) {
        $ignore = join( "|", @{ $inputs->{config}->{ignore} } );
    }

    my $callback = sub {
        my $line = $_[0];
        return if $ignore && $line =~ m|$ignore|;
        $self->logger->debug( "$self->{key}: $line" );
        push @{ $self->{react} }, { subject => $line }
    };

    $self->tail->callback(       $callback );
    $self->tail->reset_callback( $callback );

    if ( $inputs->{cache}->{position} ) {
        $self->tail->position( $inputs->{cache}->{position} );
    }

    return;
}

sub check {
    my ( $self, $inputs ) = @_;

    $self->tail->get_lines();

    $inputs->{cache}->{position} = $self->tail->position;

    if ( $self->{react} ) {
        my $return = { react => \@{ $self->{react} }, cache => $inputs->{cache} };
        undef $self->{react};
        return $return;
    }

    return { cache => $inputs->{cache} };
}

1;
