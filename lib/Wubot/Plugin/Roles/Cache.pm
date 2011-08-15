package Wubot::Plugin::Roles::Cache;
use Moose::Role;

# VERSION

use YAML;

use Wubot::Logger;

has 'cache_file' => ( is => 'ro',
                      isa => 'Str',
                      required => 1,
                  );

has 'cache_data' => ( is => 'rw',
                      isa => 'HashRef',
                      lazy => 1,
                      default => sub {
                          my $self = shift;
                          return $self->read_cache();
                      },
                  );

sub read_cache {
    my ( $self ) = @_;

    $self->logger->debug( "Reading cache: ", $self->cache_file );

    if ( ! -r $self->cache_file ) {
        $self->logger->debug( "Cache file not found: ", $self->cache_file );
        return {};
    }

    my $yaml;

    eval {                      # try
        $yaml = YAML::LoadFile( $self->cache_file );
        1;
    } or do {                   # catch
        my $error = $@;

        $self->logger->error( "ERROR: invalid cache file: ", $self->cache_file );
        $self->logger->error( $error );
        my $corrupt_cache_file = join( ".", $self->cache_file, "broken" );
        $self->logger->error( "Renaming broken cache file to: $corrupt_cache_file" );
        system( "mv", $self->cache_file, $corrupt_cache_file );
        $yaml = {};
    };

    return $yaml;
}

sub get_cache {
    my ( $self ) = @_;

    return $self->cache_data;
}

sub write_cache {
    my ( $self, $cache ) = @_;

    $self->logger->debug( "Writing cache..." );

    # store the latest check cache data
    $cache->{lastupdate} = time;

    my $tempfile = join ".", $self->cache_file, "tmp";

    $self->cache_data( $cache );

    $self->logger->debug( "Writing cache file: $tempfile" );
    YAML::DumpFile( $tempfile, $cache );

    my $cache_file = $self->cache_file;

    if ( -r $cache_file ) {
        system( "cp", $cache_file, "$cache_file.bak" );
    }

    system( "mv", $tempfile, $cache_file );

    return 1;
}

sub cache_mark_seen {
    my ( $self, $cache, $id ) = @_;

    $self->logger->trace( "Cache seen: $id" );
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
            $self->logger->trace( "Removing item from cache: $id" );
        }
    }
}


1;
