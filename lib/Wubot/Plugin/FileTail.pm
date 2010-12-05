package Wubot::Plugin::FileTail;
use Moose;

use File::Tail;
use Log::Log4perl;

has 'path' => ( is => 'rw',
                isa => 'Str',
            );

has 'tail' => ( is => 'rw',
                isa => 'File::Tail',
                lazy => 1,
                default => sub {
                    my ( $self ) = @_;

                    return File::Tail->new( name        => $self->path,
                                            nowait      => 1,
                                            interval    => 1,
                                            maxinterval => 5,
                                            adjustafter => 5,
                                            errmode     => "return",
                                        );
                }
            );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );



with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};

    my $path = $config->{path};

    unless ( -r $path ) {
        $self->logger->logdie( "ERROR: FileTail - path not readable: $path" );
    }

    unless ( $self->{tail} ) {
        $self->logger->warn( "Initializing filetail for $path" );

        $self->path( $path );

        # lazy load File::Tail object
        $self->tail;

        # don't read from the filehandle immediately after
        # initializing it, makes testing difficult
        return;
    }

    $self->logger->debug( "reading from file $path" );
    my $line = $self->tail->read;

    return unless $line;

    $self->logger->debug( "read: $line" );

    my @reactions;

    if ( $line ) {
        my $key = $self->key;
        chomp $line;

        push @reactions, { subject => $line };
    }

    return { react => \@reactions };
}

1;
