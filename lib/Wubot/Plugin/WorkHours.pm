package Wubot::Plugin::WorkHours;
use Moose;

use DBI;
use POSIX qw(strftime);

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

my $seven_days = 60 * 60 * 24 * 8;

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
        $self->{sth} = $self->{dbh}->prepare( "SELECT * FROM $config->{tablename} WHERE timestamp > $start_time ORDER BY id" );

        if ( !defined $self->{sth} ) {
            die "Cannot prepare statement: $DBI::errstr\n";
        }
    }

    $self->{sth}->execute;

    my $data;

    while ( my $row = $self->{sth}->fetchrow_hashref() ) {

        my $day = strftime( "%Y-%m-%d", localtime( $row->{timestamp} ) );

        $data->{$day}->{total}++;

        if ( $row->{idle_min} > 9 ) {
            $data->{$day}->{idle_min}++;
        }
        else {
            $data->{$day}->{active_min}++;
        }
    }

    my $react;

    my $total_idle;
    my $total_active;

    for my $day ( keys %{ $data } ) {
        if ( $data->{$day}->{idle_min} ) {
            $react->{$day}->{idle_hrs} = int( $data->{$day}->{idle_min} / 60 * 10 ) / 10;
            $total_idle += $react->{$day}->{idle_hrs};
        }

        if ( $data->{$day}->{active_min} ) {
            $react->{$day}->{active_hrs} = int( $data->{$day}->{active_min} / 60 * 10 ) / 10;
            $total_active += $react->{$day}->{active_hrs};
        }
    }

    $react->{total}->{idle}   = $total_idle;
    $react->{total}->{active} = $total_active;

    $react->{subject} = "Work hours last 7 days: idle=$total_idle active=$total_active";

    return { react => $react };
}

1;
