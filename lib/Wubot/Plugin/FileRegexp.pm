package Wubot::Plugin::FileRegexp;
use Moose;

# VERSION

use Wubot::Logger;
use Wubot::Util::Tail;

has 'path'      => ( is      => 'rw',
                     isa     => 'Str',
                     default => '',
                 );

has 'tail'      => ( is      => 'ro',
                     isa     => 'Wubot::Util::Tail',
                     lazy    => 1,
                     default => sub {
                         my ( $self ) = @_;
                         return Wubot::Util::Tail->new( { path  => $self->path } );
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

__END__

=head1 NAME

Wubot::Plugin::FileRegexp - monitor number of lines matching regular expressions in a file

=head1 DESCRIPTION

TODO: More to come...


=head1 SUBROUTINES/METHODS

=over 8

=item init( $inputs )

The standard monitor init() method.

=item check( $inputs )

The standard monitor check() method.

=back
