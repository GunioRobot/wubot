package Wubot::Plugin::EmacsOrgMode;
use Moose;

# VERSION

use Date::Manip;
use File::chdir;

use Wubot::Logger;
use Wubot::Util::Tasks;

has 'taskutil' => ( is => 'ro',
                    isa => 'Wubot::Util::Tasks',
                    lazy => 1,
                    default => sub {
                        return Wubot::Util::Tasks->new();
                    },
                );

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

    my $dir_h;

    my @react;

    my $page_count = 0;

    opendir( $dir_h, $config->{directory} ) or die "Can't opendir $config->{directory}: $!";

  FILE:
    while ( defined( my $entry = readdir( $dir_h ) ) ) {

        next unless $entry;
        next if $entry =~ m|^\.|;
        next unless $entry =~ m|org$|;

        my $updated = ( stat "$config->{directory}/$entry" )[9];

        next if exists $cache->{files}->{$entry}->{lastupdate} && $updated == $cache->{files}->{$entry}->{lastupdate};

        $cache->{files}->{$entry}->{lastupdate} = $updated;

        if ( $page_count++ > 100 ) {
            $self->logger->info( "Reached maximum page count: 100" );
            last FILE;
        }

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

        my @tasks = $self->taskutil->parse_emacs_org_page( $entry, $content );

        $self->taskutil->sync_tasks( $filename, @tasks );

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

    my $results = { cache => $cache, react => \@react };

    if ( $page_count > 100 ) {
        $self->logger->info( "Max count reached, rescheduling next check in 5 seconds" );
        $results->{delay} = 5;
    }

    return $results;
}

1;

__END__

=head1 NAME

Wubot::Plugin::EmacsOrgMode - parse tasks from Emacs Org-Mode files

=head1 DESCRIPTION

TODO: More to come...


=head1 SUBROUTINES/METHODS

=over 8

=item check( $inputs )

The standard monitor check() method.

=back
