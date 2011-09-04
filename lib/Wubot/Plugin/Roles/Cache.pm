package Wubot::Plugin::Roles::Cache;
use Moose::Role;

# VERSION

use YAML;

use Wubot::Logger;

=head1 NAME

Wubot::Plugin::Roles::Cache - role for plugins that need to cache data between runs

=head1 SYNOPSIS

    with 'Wubot::Plugin::Roles::Cache';

    # the standard monitor plugin check() method
    sub check {
        my ( $self, $inputs ) = @_;

        # monitor gets data from whatever it is monitoring, e.g. items
        # in a feed, files in a directory, etc.
        my @things = $self->get_some_things();

        # iterate through the things to determine which ones are new.
      THING:
        for my $thing ( @things ) {

            # if we've already seen this item before, move along
            if ( $self->cache_is_seen( $cache, $thing ) ) {
                $self->logger->trace( "Already seen: ", $thing );

                # touch cache time on this subject to prevent this item
                # from getting expired from the cache
                $self->cache_mark_seen( $cache, $thing );

                # nothing else to do with this one
                next THING;
            }

            # this is the first time we've seen this thing.  keep track of
            # it so we don't react to it next time this check runs
            $self->cache_mark_seen( $cache, $subject );

            # this will get returned
            push @react, { subject => "new thing: $thing" };
        }

        # delete all the cached things that we haven't seen in the
        # last 7 days
        $self->cache_expire( $cache );

        return { cache => $cache, react => \@react };

    }

=head1 DESCRIPTION

This role makes it easy for a plugin to cache data that it may need to
keep track of in-between checks.

For example, an RSS plugin monitors a feed for new articles.  Each
time it runs, it fetches a complete list of all the articles in the
feed.  Therefore, it needs to use a cache file to keep track of the
articles it has previously seen, and then only send new articles on to
the reactor for processing.


=cut

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

has 'expire_age' => ( is => 'ro',
                      isa => 'Num',
                      default => sub { 60*60*24*7 },
                  );

=head1 SUBROUTINES/METHODS

=over 8

=item $obj->read_cache( $config );

This method loads the cache data from the cache file.  This will get
called lazily the first time the cache data is accessed.

=cut

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

=item $obj->get_cache()

Return the cache data from memory.  This does not read the cache file.

=cut

sub get_cache {
    my ( $self ) = @_;

    return $self->cache_data;
}

=item $obj->write_cache( $cache )

Writes out the cache data to disk.

=cut

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

=item $obj->cache_mark_seen( $cache, $id );

Mark an item as 'seen' in the cache.

The time that the item was marked as 'seen' will be recorded in the
hash so that old items can eventually be removed.

You probably want to call this method on every item in the queue every
time the check runs, to ensure that items that currently exist won't
be expired.

=cut

sub cache_mark_seen {
    my ( $self, $cache, $id ) = @_;

    $self->logger->trace( "Cache seen: $id" );
    $cache->{seen}->{$id} = time;
}

=item $obj->cache_is_seen( $cache, $id )

Determine if the specified id already exists in the cache.

Returns undef if the item does not already exist in the cache.  If the
item does already exist in the cache, it returns the time the 'seen'
flag was last updated on the id.

=cut

sub cache_is_seen {
    my ( $self, $cache, $id ) = @_;

    return unless $cache->{seen};

    return $cache->{seen}->{$id};
}

=item $obj->cache_expire( $cache )

Expire all items in the cache where the last update time is older than
the expire_age.  By default this is 7 days.

To override the default expire_age, define an expire_age moose param
in your plugin to the number of seconds to keep untouched cache
entries.  For example,

    has 'expire_age' => ( is => 'ro',
                          isa => 'Num',
                          default => 3600,
                      );

=cut

sub cache_expire {
    my ( $self, $cache ) = @_;

    # anything older than expire_age gets expired
    my $expired = time - $self->expire_age;

    for my $id ( keys %{ $cache->{seen} } ) {
        if ( $cache->{seen}->{ $id } < $expired ) {
            delete $cache->{seen}->{ $id };
            $self->logger->trace( "Removing item from cache: $id" );
        }
    }
}


1;

__END__

=back

=head1 NOTES

If your plugin has previous cached data, then the cache file gets read
by the Wubot::Check library prior to calling your plugin's check()
method.  If you want to write data out to the cache, simply include it
in the 'cache' key in your check() method's returned hash data.  See
the example for more details.

Note that the cache data is written out as a YAML file each time your
check runs.  This can be expensive if you are caching a large amount
of data (or a moderately large amount of data for a check that runs
frequently).  If that is the case, then you may want to implement a
more efficient caching method.

=cut
