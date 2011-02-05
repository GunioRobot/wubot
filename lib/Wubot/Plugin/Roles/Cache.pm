package Wubot::Plugin::Roles::Cache;
use Moose::Role;

use YAML;

has 'cache_file' => ( is => 'ro',
                      isa => 'Str',
                      required => 1,
                  );

sub get_cache {
    my ( $self ) = @_;

    $self->logger->debug( "Reading cache: ", $self->cache_file );

    if ( ! -r $self->cache_file ) {
        $self->logger->debug( "Cache file not found: ", $self->cache_file );
        return {};
    }

    my $cache = YAML::LoadFile( $self->cache_file );

    # todo: handle broken cache file

    return $cache;
}

sub write_cache {
    my ( $self, $cache ) = @_;

    $self->logger->debug( "Writing cache..." );

    # store the latest check cache data
    $cache->{lastupdate} = time;

    my $tempfile = join ".", $self->cache_file, "tmp";

    YAML::DumpFile( $tempfile, $cache );

    my $cache_file = $self->cache_file;

    if ( -r $cache_file ) {
        system( "cp", $cache_file, "$cache_file.bak" );
    }

    system( "mv", $tempfile, $cache_file );
}

sub cache_mark_seen {
    my ( $self, $cache, $id ) = @_;

    $self->logger->debug( "Cache seen: $id" );
    $cache->{seen}->{$id} = time;

}

sub cache_is_seen {
    my ( $self, $cache, $id ) = @_;

    return unless $cache->{seen};

    return $cache->{seen}->{$id};
}

sub cache_expire {
    my ( $self, $cache ) = @_;

    # anything older than 7 days ago is expired
    my $expired = time - 60*60*24*7;

    for my $id ( keys %{ $cache->{seen} } ) {
        if ( $cache->{seen}->{ $id } < $expired ) {
            delete $cache->{seen}->{ $id };
            $self->logger->debug( "Removing item from cache: $id" );
        }
    }
}


1;
