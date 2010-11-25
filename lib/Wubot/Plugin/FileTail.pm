package Wubot::Plugin::FileTail;
use Moose;

use Log::Log4perl;
use File::Tail;

has 'key'      => ( is => 'ro',
                    isa => 'Str',
                    required => 1,
                );

has 'path' => ( is => 'rw',
                isa => 'Str',
            );

has 'tail' => ( is => 'rw',
                isa => 'File::Tail',
                lazy => 1,
                default => sub {
                    my ( $self ) = @_;
                    return File::Tail->new( name   => $self->path,
                                            nowait => 1,
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



sub check {
    my ( $self, $config, $cache ) = @_;

    $self->path( $config->{path} );

    unless ( -r $self->path ) {
        $self->logger->error( "Tail: path not readable: $self->{path}" );
        return;
    }

    my $line = $self->tail->read;

    if ( $line ) {
        my $key = $self->key;
        chomp $line;
        $self->logger->info( "$key: $line" );
    }

    return $cache;
}

1;
