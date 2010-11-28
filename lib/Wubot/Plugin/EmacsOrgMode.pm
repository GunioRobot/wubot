package Wubot::Plugin::EmacsOrgMode;
use Moose;

use File::chdir;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

    my $dir_h;

    my @react;

  FILE:
    opendir( $dir_h, $config->{directory} ) or die "Can't opendir $config->{directory}: $!";
    while ( defined( my $entry = readdir( $dir_h ) ) ) {
        next unless $entry;
        next if $entry =~ m|^\.|;
        next unless $entry =~ m|org$|;

        my $updated = ( stat "$config->{directory}/$entry" )[9];

        next if exists $cache->{files}->{$entry}->{lastupdate} && $updated == $cache->{files}->{$entry}->{lastupdate};

        $cache->{files}->{$entry}->{lastupdate} = $updated;

        $self->logger->info( "Checking updated file: $config->{directory}/$entry => $updated" );

        open(my $fh, "<", "$config->{directory}/$entry" )
            or die "Couldn't open $config->{directory}/$entry for reading: $!\n";

        my $content;
        while ( my $line = <$fh> ) {
            $content .= "$line";
        }

        close $fh or die "Error closing file: $!\n";

        my $name = $entry;
        $name =~ s|.org$||;

        # the task is 'done' until any incomplete tasks are found
        my $done = 1;
        my $color;
        if ( $content =~ m|^\s+\-\s\[\s\]\s|m ) {
            $done = 0;

            if ( $entry =~ m|^\d\d\d\d\.\d\d\.\d\d| ) {
                $color = 'yellow';
            }
            else {
                $color = 'blue';
            }
        }
        else {
            if ( $entry =~ m|^\d\d\d\d\.\d\d\.\d\d| ) {
                $color = 'green';
            }
            else {
                $color = '';
            }
        }

        for my $block ( split /\n\*+\s/, $content ) {

            $block =~ s|^\s+\*\s+||mg;

            $block =~ m|^(\w+)|;
            my $name = $1;

            next unless $name;

            if ( $name =~ m|meta|i ) {
                if ( $block =~ m|^\s+\-\scolor\:\s([\w]+)$|m ) {
                    $color = "$1";
                }
            }
        }

        push @react, { name      => $name,
                       timestamp => $updated,
                       subject   => "org file updated: $entry",
                       body      => $content,
                       done      => $done,
                       color     => $color,
                   };

        # attempt to commit file to git if it isn't already
        local $CWD = $config->{directory};

        if ( $config->{git} ) {
            system( "git", "add", $entry );
            system( "git", "commit", "-m", "$entry committed by wubot" );
        }
    }
    closedir( $dir_h );

    return { cache => $cache, react => \@react };
}

1;
