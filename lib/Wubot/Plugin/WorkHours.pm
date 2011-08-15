package Wubot::Plugin::WorkHours;
use Moose;

# VERSION

use DBI;
use POSIX qw(strftime);

use Wubot::Logger;
use Wubot::SQLite;

has 'sql'    => ( is      => 'ro',
                  isa     => 'Wubot::SQLite',
                  lazy    => 1,
                  default => sub {
                      return Wubot::SQLite->new( { file => $_[0]->dbfile } );
                  },
              );

has 'dbfile' => ( is      => 'rw',
                  isa     => 'Str',
              );

has 'period' => ( is      => 'rw',
                  isa     => 'Num',
                  lazy    => 1,
                  default => sub {
                      return 60 * 60 * 24 * 7;
                  },
              );

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    $self->dbfile( $config->{dbfile} );

    my $period     = $config->{period} || $self->period;
    my $now        = time;
    my $start_time = $now - $period;

    my @rows;

    $self->sql->select( { tablename => $config->{tablename},
                          where     => { 'lastupdate' => { '>', $start_time } },
                          order     => 'lastupdate',
                          callback  => sub { push @rows, $_[0] },
                      } );

    return { react => $self->calculate_stats( \@rows ) };
}

sub calculate_stats {
    my ( $self, $rows ) = @_;

    my $data;

    my $last_timestamp = 0;

    for my $row ( @{ $rows } ) {

        my $day = strftime( "%Y-%m-%d", localtime( $row->{lastupdate} ) );

        my $seconds_diff = $row->{lastupdate} - $last_timestamp;

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

        $last_timestamp = $row->{lastupdate};
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


__END__


=head1 NAME

Wubot::Plugin::WorkHours - track of the number of hours you are active/idle


=head1 SYNOPSIS

  ~/wubot/config/plugins//WorkHours/myhost.yaml

  ---
  tablename: idle
  dbfile: /Users/wu/wubot/sqlite/idle.sql
  delay: 10m

=head1 DESCRIPTION

In order to use this plugin, you must have enabled an idle plugin
monitor such as L<Wubot::Plugin::OsxIdle>.

You will also need a rule that saves the idle time into a sqlite
database, e.g.:

  - name: OS X Idle
    condition: key matches ^OsxIdle
    rules:
      - name: store in SQLite database
        plugin: SQLite
        config:
          file: /usr/home/wu/wubot/sqlite/idle.sql
          tablename: idle

The 'idle' table schema is distributed in the wubot tarball, in the
config/schema subdirectory.  Please copy all schemas in that directory
to ~/wubot/schemas/.

Once you have the idle plugin saving data to a sqlite database, and
you have enabled the WorkHours monitor using the config above, then
you can use the following reactor rules to build the workhours graphs
and to store your workhours data in a SQLite database.

  - name: Work Hours
    condition: key matches ^WorkHours
    rules:

      - name: store in SQLite
        plugin: SQLite
        config:
          file: /usr/home/wu/wubot/sqlite/workhours.sql
          tablename: workhours

      - name: store and graph with RRD
        plugin: RRD
        config:
          base_dir: /usr/home/wu/wubot/rrd
          fields:
            idle_hours: GAUGE
            active_hours: GAUGE
          period:
            - day
            - week
            - month
          heartbeat: 1800
          graph_options:
            sources:
              - active_hours
              - idle_hours
            source_colors:
              - FF9933
              - 9933FF
            source_drawtypes:
              - AREA
              - LINE
            right-axis: 1:0
            width: 375
