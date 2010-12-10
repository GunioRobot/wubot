package Wubot::Plugin::WorkHours;
use Moose;

use DBI;
use POSIX qw(strftime);

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

my $seven_days = 60 * 60 * 24 * 7;

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    unless ( $self->{dbh} ) {
        $self->{dbh} = DBI->connect("dbi:Pg:dbname=$config->{dbname};host=$config->{host};port=$config->{port};options=''",
                                    $config->{user},
                                    "",
                                    { AutoCommit         => 1,
                                      RaiseError         => 1,
                                      PrintError         => 1,
                                      ChopBlanks         => 1,
                                      ShowErrorStatement => 0,
                                      pg_enable_utf8     => 1,
                                  } );
    }

    my $now = time;

    # working time over last 7 days
    my $start_time = $now - $seven_days;

    unless ( $self->{sth} ) {
        $self->{sth} = $self->{dbh}->prepare( "SELECT * FROM $config->{tablename} WHERE timestamp > $start_time ORDER BY timestamp" );

        if ( !defined $self->{sth} ) {
            die "Cannot prepare statement: $DBI::errstr\n";
        }
    }

    $self->{sth}->execute;

    my @rows;

    while ( my $row = $self->{sth}->fetchrow_hashref() ) {

        push @rows, $row;

    }

    return { react => $self->calculate_stats( \@rows ) };
}

sub calculate_stats {
    my ( $self, $rows ) = @_;

    my $data;

    my $last_timestamp = 0;

    for my $row ( @{ $rows } ) {

        my $day = strftime( "%Y-%m-%d", localtime( $row->{timestamp} ) );

        my $seconds_diff = $row->{timestamp} - $last_timestamp;

        my $counter = 1;
        if ( $seconds_diff > 60 && $seconds_diff < 600 ) {
            $counter = $seconds_diff / 60;
        }

        $data->{total}->{total_min} += $counter;
        $data->{$day}->{total_min}  += $counter;

        if ( $row->{idle_min} > 9 ) {
            $data->{total}->{idle_min} += $counter;
            $data->{$day}->{idle_min}  += $counter;
        }
        else {
            $data->{total}->{active_min} += $counter;
            $data->{$day}->{active_min}  += $counter;
        }

        $last_timestamp = $row->{timestamp};
    }

    for my $day ( keys %{ $data } ) {

        $data->{$day}->{idle_hours}   = int( ( $data->{$day}->{idle_min}   || 0 ) / 60 * 10 ) / 10;
        delete $data->{$day}->{idle_min};

        $data->{$day}->{active_hours} = int( ( $data->{$day}->{active_min} || 0 ) / 60 * 10 ) / 10;
        delete $data->{$day}->{active_min};

        $data->{$day}->{total_hours}  = int( ( $data->{$day}->{total_min}  || 0 ) / 60 * 10 ) / 10;
        delete $data->{$day}->{total_min};
    }

    for my $key ( keys %{ $data->{total} } ) {
        $data->{$key} = $data->{total}->{$key};
    }
    delete $data->{total};

    return $data;
}

1;
