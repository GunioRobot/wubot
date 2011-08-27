package Wubot::Plugin::Pulse;
use Moose;

# VERSION

use POSIX qw(strftime);

use Wubot::Logger;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my @messages;

    my $cache = $inputs->{cache};

    my $now = $inputs->{now} || time;

    my $lastupdate = $cache->{lastupdate} || $now;

    # the number of minutes that have occurred on the clock since the
    # last notification.
    my $seconds = strftime( "%S", localtime( $now ) );

    my $diff = $now - $lastupdate;
    my $minutes_old = int( $diff / 60 );
    $self->logger->debug( "minutes old: $minutes_old => $diff diff seconds, $seconds seconds past minute" );

    my @minutes;
    if ( ! $cache->{lastupdate} ) {
        $self->logger->warn( "Pulse: no pulse cache data found, first pulse" );
        @minutes = ( 0 );
        $minutes_old = 0;
    }
    elsif ( $minutes_old ) {
        if ( $minutes_old > 10 ) {
            $self->logger->error( "Minutes since last pulse: $minutes_old" );
        }
        elsif ( $minutes_old > 1 ) {
            $self->logger->info( "Minutes since last pulse: $minutes_old" );
        }
        @minutes = reverse ( 0 .. $minutes_old - 1 );

        $self->logger->trace( "updating lastupdate to: ", scalar localtime $now );
    }
    else {
        # we have already sent the pulse for this minute
        @minutes = ();
    }

    # set the 'lastupdate' time to be the beginning of the current minute
    $cache->{lastupdate} = $now - $seconds;

    for my $age ( @minutes ) {

        my $pulse_time = $now - $age * 60;

        my $date = strftime( "%Y-%m-%d", localtime( $pulse_time ) );

        my $time = strftime( "%H:%M", localtime( $pulse_time ) );

        my $weekday = lc( strftime( "%A", localtime( $pulse_time ) ) );

        $self->logger->info( "Sending pulse for: $date $time" );

        my $message = { date => $date,
                        time => $time,
                        day  => $weekday,
                        age  => $age,
                        coalesce => $self->key,
                    };

        push @messages, $message;
    }

    # attempt to sync up pulses with the minute
    my $second = strftime( "%S", localtime() );
    my $delay = 60 - $second;

    return { react => \@messages, cache => $cache, delay => $delay };
}

1;

__END__


=head1 NAME

Wubot::Plugin::Pulse - send a message once per minute


=head1 SYNOPSIS

  # The plugin configuration lives here:
  ~/wubot/config/plugins/Pulse/myhostname.yaml

  # There is no actual configuration for this plugin.  All that is
  # needed is that a minimal configuration file exist:
  ---
  enable: 1

  # an example message:

  age: 0
  checksum: ae947857531889e0fb55a517c4e0fc94
  date: 2011-07-31
  day: sunday
  hostname: myhostname
  key: Pulse-myhostname
  lastupdate: 1312158327
  plugin: Wubot::Plugin::Pulse
  time: 17:25


=head1 DESCRIPTION


The 'pulse' plugin sends a message once per minute.  The message
contains the following fields:

  date: yyyy-mm-dd
  time: hh:mm
  day: xday

The 'day' field will contain the full weekday name in lower case.

The message can be used within the reactor to trigger jobs to start at
certain times or dates.

Each time the Pulse plugin runs, it will reschedule itself to run
again at the minute change.

There is no guarantee that the pulse will occur on time, but there is
a guarantee that no minutes will be skipped.  When the Pulse plugin
runs, it checks the cache to find the last time it was run.  If any
pulses were missed (e.g. because wubot was not running or was unable
to run the Pulse for a minute), then the Pulse check will immediately
send messages for all the missed minutes.  If the pulse was triggered
late, then the 'age' field on the message will indicate the number of
minutes old that the message was at the time it was generated.  If the
'age' field is false, that indicates that the message was sent during
the minute that was indicated on the message.

