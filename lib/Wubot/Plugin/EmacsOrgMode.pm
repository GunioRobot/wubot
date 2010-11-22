package Wubot::Plugin::EmacsOrgMode;
use Moose;

use File::chdir;

sub check {
    my ( $self, $config, $cache ) = @_;

    my @results;

    my $dir_h;

  FILE:
    opendir( $dir_h, $config->{directory} ) or die "Can't opendir $config->{directory}: $!";
    while ( defined( my $entry = readdir( $dir_h ) ) ) {
        next unless $entry;
        next if $entry =~ m|^\.|;
        next unless $entry =~ m|org$|;

        my $updated = ( stat "$config->{directory}/$entry" )[9];

        next if exists $cache->{files}->{$entry}->{lastupdate} && $updated == $cache->{files}->{$entry}->{lastupdate};

        $cache->{files}->{$entry}->{lastupdate} = $updated;

        print "Checking updated file: $config->{directory}/$entry => $updated\n";

        open(my $fh, "<", "$config->{directory}/$entry" )
            or die "Couldn't open $config->{directory}/$entry for reading: $!\n";

        my $content;
        while ( my $line = <$fh> ) {
            $content .= "$line";
        }

        close $fh or die "Error closing file: $!\n";

        my $name = $entry;
        $name =~ s|.org$||;

        push @results, { name      => $name,
                         timestamp => $updated,
                         subject   => "org file updated: $entry",
                         body      => $content,
                     };

        # attempt to commit file to git if it isn't already
        local $CWD = $config->{directory};

        system( "git", "add", $entry );
        system( "git", "commit", "-m", "$entry committed by wubot" );
    }
    closedir( $dir_h );


    return ( \@results, $cache );
}

1;
