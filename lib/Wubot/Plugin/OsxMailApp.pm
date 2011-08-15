package Wubot::Plugin::OsxMailApp;
use Moose;

# VERSION

use Date::Manip;

use Wubot::Logger;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

my $keys = { date    => 1,
             from    => 1,
             subject => 1,
             to      => 1,
             cc      => 1,
         };

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    my @react;

    my $directory = $config->{directory};

    $self->logger->debug( "Opening directory: $directory" );

    # quickly get a list of files and then close the directory
    my @files;
    my $dir_h;
    opendir( $dir_h, $directory ) or die "Can't opendir $directory: $!";
    while ( defined( my $entry = readdir( $dir_h ) ) ) {
        next unless $entry;
        next unless $entry =~ m|.emlx$|;
        # ignore messages we've already seen
        if ( $self->cache_is_seen( $cache, $entry ) ) {
            # update the last seen time
            $self->cache_mark_seen( $cache, $entry );
            next;
        }
        push @files, $entry;
    }
    closedir( $dir_h );

    my $now = time;

  MESSAGE:
    for my $entry ( @files ) {

        my $path = "$directory/$entry";

        open(my $fh, "<", $path)
            or die "Couldn't open $path for reading: $!\n";

        my $data;

        while ( my $line = <$fh> ) {

            chomp $line;

            # stop at the last line of the headers
            last unless $line;

            if ( $line =~ m|^(\w+)\:\s(.*)$| ) {

                my $param = lc( $1 );
                my $value = $2;

                # check if this is an interesting key
                next unless $keys->{ $param };

                # save the field data
                $data->{ $param } = $value;
            }
        }

        # use 'username' for 'from' field
        $data->{username} = $data->{from};

        # parse the date stamp
        $data->{lastupdate} = UnixDate( ParseDate( $data->{date} ), "%s" );

        push @react, $data;

        close $fh or die "Error closing file: $!\n";

        # cache this new id
        $self->cache_mark_seen( $cache, $entry );
    }

    return { cache => $cache, react => \@react };
}

1;
