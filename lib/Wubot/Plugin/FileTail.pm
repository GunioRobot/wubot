package Wubot::Plugin::FileTail;
use Moose;

use File::Tail;

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

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';
with 'Wubot::Plugin::Roles::Reactor';


sub check {
    my ( $self, $config ) = @_;

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

    return 1;
}

1;
