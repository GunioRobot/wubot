package Wubot::Plugin::Pulse;
use Moose;

# VERSION

use POSIX qw(strftime);

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my @messages;

    my $cache = $inputs->{cache};

    my $now = time;

    my $lastupdate = $cache->{lastupdate} || $now;

    my $minutes_old = int( ( $now - $lastupdate ) / 60 );
    $self->logger->debug( "minutes old: $minutes_old" );

    my @minutes;
    if ( ! $cache->{lastupdate} ) {
        @minutes = ( 0 );
    }
    elsif ( $minutes_old ) {
        @minutes = reverse ( 0 .. $minutes_old - 1 );
    }
    else {
        @minutes = ();
    }

    for my $age ( @minutes ) {

        my $pulse_time = $now - $age * 60;

        my $date = strftime( "%Y-%m-%d", localtime( $pulse_time ) );

        my $time = strftime( "%H:%M", localtime( $pulse_time ) );

        $self->logger->debug( "Sending pulse for: $date $time" );

        my $message = { date => $date,
                        time => $time,
                        age  => $age,
                    };

        push @messages, $message;
    }

    $cache->{lastupdate} = $now;

    # attempt to sync up pulses with the minute
    my $second = strftime( "%S", localtime() );
    my $delay = 60 - $second;

    return { react => \@messages, cache => $cache, delay => $delay };
}

1;

