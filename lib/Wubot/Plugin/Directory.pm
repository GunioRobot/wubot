package Wubot::Plugin::Directory;
use Moose;

# VERSION

use Wubot::Logger;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

    my $directory = $config->{path};

    unless ( -d $directory ) {
        my $subject = "Error: directory not found: $directory";
        $self->logger->error( $self->key . ": $subject" );
        return { cache => $cache, react => { subject => $subject } };
    }

    my @react;

    my $dir_h;
    opendir( $dir_h, $directory ) or die "Can't opendir $directory: $!";

  ENTRY:
    while ( defined( my $entry = readdir( $dir_h ) ) ) {

        next unless $entry;
        if ( $entry eq "." || $entry eq ".." ) { next }

        # if we've already seen this item, move along
        if ( $self->cache_is_seen( $cache, $entry ) ) {
            $self->logger->trace( "Already seen: ", $entry );

            # touch cache time on this subject
            $self->cache_mark_seen( $cache, $entry );

            next ENTRY;
        }

        # this item is still in the directory
        $self->cache_mark_seen( $cache, $entry );

        push @react, { file => $entry, subject => "New: $entry" };

    }

    $self->cache_expire( $cache );

    return { cache => $cache, react => \@react };
}



1;
