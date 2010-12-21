package Wubot::Plugin::SunRise;
use Moose;

use Astro::Sunrise;
use Date::Manip;
use POSIX qw(strftime);

use Wubot::TimeLength;

has 'timelength' => ( is => 'ro',
                      isa => 'Wubot::TimeLength',
                      lazy => 1,
                      default => sub { return Wubot::TimeLength->new(); },
                  );

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};

    my $now  = time;

    my $message = {};

    # if the next sunrise/sunset event listed in the cache is in the
    # future, then use that date instead of re-calculating
    if ( $cache->{next_utime} && $cache->{next_utime} > $now ) {

        $message = $inputs->{cache};

        $message->{cache_remaining} = $cache->{next_utime} - $now;

        my $diff = $message->{next_utime} - $now;
        $message->{diff} = $diff;

        my $mins = int( $diff / 60 );

        # send a message when there is a round number of hours before
        # the next sunrise/sunset
        return unless $mins % 60 == 0;

        my $diff_time = $self->timelength->get_human_readable( $mins*60 );
        $message->{subject} = "$cache->{next} in $diff_time";
        return { react => $message };
    }


    my $config = $inputs->{config};

    $message->{sunrise} = sun_rise( $config->{longitude}, $config->{latitude} );
    $message->{sunset}  = sun_set(  $config->{longitude}, $config->{latitude} );

    my $time = strftime( "%H:%M", localtime( $now ) );

    # if after sunset, get next sunrise time
    if ( $time gt $message->{sunset} ) {

        $message->{after_sunset} = 1;
        $message->{sunrise} = sun_rise( $config->{longitude}, $config->{latitude}, 0, 1 );

        $message->{next}       = 'sunrise';
        $message->{next_utime} = UnixDate( ParseDate( "tomorrow $message->{sunrise}" ), "%s" );
        $message->{next_until} = $self->timelength->get_human_readable( $message->{next_utime} - $now );

        $message->{subject}    = "$message->{next} in $message->{next_until}";
    }
    elsif ( $time lt $message->{sunrise} ) {
        $message->{before_sunrise} = 1;

        $message->{next}       = 'sunrise';
        $message->{next_utime} = UnixDate( ParseDate( $message->{sunrise} ), "%s" );
        $message->{next_until} = $self->timelength->get_human_readable( $message->{next_utime} - $now );

        $message->{subject}    = "$message->{next} in $message->{next_until}";
    }
    else {
        $message->{daytime} = 1;

        $message->{next}       = 'sunset';
        $message->{next_utime} = UnixDate( ParseDate( $message->{sunset} ), "%s" );
        $message->{next_until} = $self->timelength->get_human_readable( $message->{next_utime} - $now );

        $message->{subject}    = "$message->{next} in $message->{next_until}";
    }

    return { react => $message, cache => $message };
}

1;
