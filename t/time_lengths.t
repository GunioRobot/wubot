#!/perl
use strict;

use Test::Exception;
use Test::More 'no_plan';

use Wubot::TimeLength;

ok( my $timelength = Wubot::TimeLength->new(),
    "Creating a new Wubot::TimeLength object"
);

# human readable string in most appropriate units
{
    is( $timelength->get_human_readable( 60 ),
        "1m",
        "Human-readable time for 1 minute"
    );

    is( $timelength->get_human_readable( 90 ),
        "1m30s",
        "Human-readable time for 1.5 minutes"
    );

    is( $timelength->get_human_readable( 60*60 ),
        "1h",
        "Human-readable time for 1 hour"
    );

    is( $timelength->get_human_readable( '1.5h' ),
        "1h30m",
        "Human-readable time for 1.5 hours"
    );

    is( $timelength->get_human_readable( 60*60*1.5 ),
        "1h30m",
        "Human-readable time for 1h 30m"
    );

    is( $timelength->get_human_readable( 60*60*24 ),
        "1d",
        "Human-readable time for 1 day"
    );

    is( $timelength->get_human_readable( 60*60*24*1.5 ),
        "1d12h",
        "Human-readable time for 1.5 days"
    );

    is( $timelength->get_human_readable( 0 ),
        "0s",
        "Human-readable time for 0s"
    );

    is( $timelength->get_human_readable( '0s' ),
        "0s",
        "Human-readable time for 0s"
    );

    is( $timelength->get_human_readable( 's' ),
        "0s",
        "Human-readable time for 0s"
    );

}

# hours
{
    is( $timelength->get_hours( 60 ),
        "0",
        "hours: 1 minute"
    );

    is( $timelength->get_hours( 60*60 ),
        "1",
        "hours: 1 hour"
    );

    is( $timelength->get_hours( 60*60*1.5 ),
        "1.5",
        "hours: 1.5 hours"
    );

    is( $timelength->get_hours( 60*60*24 ),
        "24",
        "hours: 24 hours"
    );



}

# seconds
{
    is( $timelength->get_seconds( 60 ),
        60,
        "seconds: 60 seconds"
    );

    is( $timelength->get_seconds( '1m' ),
        60,
        "seconds: 1m"
    );

    is( $timelength->get_seconds( '1h' ),
        60*60,
        "seconds: 1h"
    );

    is( $timelength->get_seconds( '1d' ),
        60*60*24,
        "seconds: 1d"
    );

    throws_ok( sub { $timelength->get_seconds( '1x' ) },
               qr/unable to parse time/,
               "Checking that 1x throws 'unable to parse time' exception"
           );

}
