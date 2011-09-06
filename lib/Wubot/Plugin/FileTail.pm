package Wubot::Plugin::FileTail;
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
                         return Wubot::Util::Tail->new( { path           => $self->path,
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

__END__

=head1 NAME

Wubot::Plugin::FileTail - monitor a log file for all new lines

=head1 SYNOPSIS

  ~/wubot/config/plugins/FileTail/bsd-01.messages.yaml

  ---
  delay: 30
  path: /var/log/messages
  ignore:
    - my.ignore.string
    - some\sregexp\d+

=head1 DESCRIPTION

Monitor a log file for new lines.

Each time a new line is seen in the file, a message will be sent
containing the fields:

  subject: {line}

If 'ignore' is defined in your configuration, then it should be set to
an array of regular expressions.  If any of the regular expressions
matches, then no message will be sent.  All patterns in the 'ignore'
array will get joined together with '|' and evaluated as a single
regular expression.


=head1 SUBROUTINES/METHODS

=over 8

=item init( $inputs )

The standard monitor init() method.

=item check( $inputs )

The standard monitor check() method.

=back
