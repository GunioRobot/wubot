package Wubot::Plugin::EmacsOrgMode;
use Moose;

# VERSION

use Date::Manip;
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

        my $filename = $entry;
        $filename =~ s|.org$||;

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

        my @tasks;

        for my $block ( split /(?:^|\n)\*+\s/, $content ) {

            $block =~ s|^\s*\*\s+||mg;

            $block =~ m|^(\w+)|;
            my $name = $1;

            next unless $name;

            if ( $name =~ m|meta|i ) {
                if ( $block =~ m|^\s+\-\scolor\:\s([\w]+)$|m ) {
                    $color = "$1";
                }
            }
            elsif ( $name eq "TODO" || $name eq "DONE" ) {

                #next if $name eq "DONE";

                $block =~ s|^\w+\s+||;

                my $task;
                $task->{type} = 'task';

                my $priorities = { C => 0, B => 1, A => 2 };
                if ( $block =~ s|^\[\#(\w)\]\s|| ) {
                    $task->{priority} = $priorities->{ $1 };
                }
                else {
                    $task->{priority} = -1;
                }

                if ( $block =~ s|^((?:\d+[smhd])+)\s|| ) {
                    $task->{duration} = $1;
                }

                $task->{status} = lc( $name );

                $task->{file} = $filename;

                $block =~ s|^(.*)||;
                $task->{title} = $1;

                if ( $task->{title} =~ s|\s*\[(\d+.*?)\]\s*$|| ) {
                    $task->{progress} = $1;
                }

                $task->{taskid} = join( ".", $task->{file}, $task->{title} );

                # deadline may be listed before or after schedule.
                # this is an ugly solution that gets it either way
                if ( $block =~ s|^\s+DEADLINE\:\s\<(.*?)(?:\s\.?(\+\d+\w))?\>||m ) {
                    $task->{deadline_text} = $1;
                    $task->{deadline}      = UnixDate( ParseDate( $1 ), "%s" );
                    $task->{deadline_recurrence}    = $2;
                }
                if ( $block =~ s|^\s+SCHEDULED\:\s\<(.*?)(?:\s\.?(\+\d+\w))?\>||m ) {
                    $task->{scheduled_text} = $1;
                    $task->{scheduled}      = UnixDate( ParseDate( $1 ), "%s" );
                    $task->{scheduled_recurrence}     = $2;
                }
                if ( $block =~ s|^\s+DEADLINE\:\s\<(.*?)(?:\s\.?(\+\d+\w))?\>||m ) {
                    $task->{deadline_text} = $1;
                    $task->{deadline}      = UnixDate( ParseDate( $1 ), "%s" );
                    $task->{deadline_recurrence}    = $2;
                }

                $block =~ s|^\s+\- State "DONE"\s+from "TODO"\s+\[.*$||mg;

                $block =~ s|^\s+\n||s;

                $task->{body} = $block;

                push @tasks, $task;
            }

        }

        push @react, { name      => $filename,
                       file      => $filename,
                       type      => 'org',
                       timestamp => $updated,
                       subject   => "org file updated: $entry",
                       body      => $content,
                       done      => $done,
                       color     => $color,
                   };

        if ( scalar @tasks ) {
            push @react, @tasks;
        }

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
