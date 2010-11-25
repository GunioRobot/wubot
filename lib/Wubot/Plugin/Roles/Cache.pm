package Wubot::Plugin::Roles::Cache;
use Moose::Role;

use YAML;

has 'cache'      => ( is => 'rw',
                      isa => 'HashRef',
                      default => sub { return $_[0]->get_cache() },
                  );

has 'cache_file' => ( is => 'ro',
                      isa => 'Str',
                      required => 1,
                  );

sub get_cache {
    my ( $self ) = @_;

    $self->logger->debug( "Reading cache: ", $self->cache_file );

    if ( -r $self->cache_file ) {
        $self->cache( YAML::LoadFile( $self->cache_file ) );
    }

    $self->logger->debug( "Cache file not found" );

    return {};
}

sub write_cache {
    my ( $self ) = @_;

    $self->logger->debug( "Writing cache..." );

    # store the latest check cache data
    $self->cache->{lastupdate} = time;

    YAML::DumpFile( $self->cache_file, $self->cache );
}

sub cache_mark_seen {
    my ( $self, $id ) = @_;

    $self->logger->debug( "Cache seen: $id" );
    $self->cache->{seen}->{$id} = time;

}

sub cache_is_seen {
    my ( $self, $id ) = @_;

    return unless $self->cache->{seen};

    return $self->cache->{seen}->{$id};
}

sub cache_expire {
    my ( $self ) = @_;

    # anything older than 7 days ago is expired
    my $expired = time - 60*60*24*7;

    for my $id ( keys %{ $self->cache->{seen} } ) {
        if ( $self->cache->{seen}->{ $id } < $expired ) {
            delete $self->cache->{seen}->{ $id };
            $self->logger->debug( "Removing item from cache: $id" );
        }
    }
}


1;
