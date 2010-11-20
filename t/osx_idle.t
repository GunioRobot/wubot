#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';
use Test::Differences;
use YAML;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
my $cache_file = "$tempdir/storage.yaml";

use Wubot::Check;

{
    my $reaction = [];
    ok( my $check = Wubot::Check->new( { class      => 'Wubot::Plugin::OsxIdle',
                                                  cache_file => $cache_file,
                                                  reactor    => sub { push @{ $reaction }, $_[0] },
                                              } ),
        "Creating a new OSX Idle check instance"
    );

    ok( my $results = $check->check( {} ),
        "Calling check() method"
    );

    my $details = ( @{ $results } )[0];

    ok( exists $details->{idle_min},
        "Checking that check returned idle minutes: $details->{idle_min}"
    );

    like( $details->{idle_min},
          qr/^\d+$/,
          "Checking that check returned a number of idle minutes"
      );

    ok( exists $details->{idle_sec},
        "Checking that check returned idle seconds: $details->{idle_sec}"
    );

    like( $details->{idle_sec},
          qr/^\d+$/,
          "Checking that check returned a number of idle seconds"
      );

}

{
    ok( my $idle = Wubot::Plugin::OsxIdle->new(),
        "Creating an OSX Idle plugin directly"
    );

    my $now = time;

    is( $idle->calculate_idle_stats( $now, 0, {}, {} )->{idle_min},
        0,
        "Checking that calculate_idle_status calculated idle_min for 0 seconds"
    );

    is( $idle->calculate_idle_stats( $now, 60, {}, {} )->{idle_min},
        1,
        "Checking that calculate_idle_status calculated idle_min for 60 seconds"
    );

    is( $idle->calculate_idle_stats( $now, 23, {}, {} )->{idle_sec},
        23,
        "Checking that calculate_idle_status included idle_sec"
    );
}


# active duration
{
    ok( my $idle = Wubot::Plugin::OsxIdle->new(),
        "Creating an OSX Idle plugin directly"
    );

    my $now = time;

    is( $idle->calculate_idle_stats( $now, 0, {}, {} )->{active_min},
        0,
        "Checking that calculate_idle_status calculated initial active_state_min as 0"
    );

    is( $idle->calculate_idle_stats( $now, 0, {}, {} )->{idle_state},
        0,
        "Checking that calculate_idle_status set idle_state false with no idle time"
    );

    is( $idle->calculate_idle_stats( $now, 600, {}, {} )->{idle_state},
        1,
        "Checking that calculate_idle_status set idle_state after 10 minutes"
    );

    is( $idle->calculate_idle_stats( $now, 600, {}, {} )->{lastupdate},
        $now,
        "Checking that calculate_idle_status set lastupdate to current time"
    );

    is( $idle->calculate_idle_stats( $now, 0, {}, { lastupdate => $now-601, active_since => $now-601 } )->{active_since},
        $now,
        "Checking that calculate_idle_status reset active_since when data is expired"
    );

    is( $idle->calculate_idle_stats( $now, 0, {}, { lastupdate => $now-601, active_since => $now-601 } )->{cache_expired},
        1,
        "Checking that calculate_idle_status set cache_expired flag when cache is too old"
    );

    is( $idle->calculate_idle_stats( $now, 0, {}, { lastupdate => $now-60, cache_expired => 1 } )->{cache_expired},
        undef,
        "Checking that calculate_idle_status cleared cache_expired flag when cache is fresh"
    );

    is( $idle->calculate_idle_stats( $now, 0, {}, { lastupdate => $now-601, active_since => $now-601 } )->{active_since},
        $now,
        "Checking that calculate_idle_status reset active_since when data is expired"
    );

    is( $idle->calculate_idle_stats( $now, 600, {}, { active_since => $now-601 } )->{active_since},
        undef,
        "Checking that calculate_idle_status cleared active_since when going idle"
    );

    is( $idle->calculate_idle_stats( $now, 0, {}, { active_since => $now-60 } )->{active_since},
        $now-60,
        "Checking that calculate_idle_status did not touch active_since when not idle"
    );

    is( $idle->calculate_idle_stats( $now, 0, {}, {} )->{active_since},
        $now,
        "Checking that calculate_idle_status calculated initial active_since using current time"
    );

    is( $idle->calculate_idle_stats( $now, 0, {}, { idle_since => $now-601 } )->{idle_since},
        undef,
        "Checking that calculate_idle_status cleared idle_since when going active"
    );

    is( $idle->calculate_idle_stats( $now, 60*3, {}, { active_since => $now-60*5 } )->{active_min},
        2,
        "Checking that calculate_idle_status calculated subtracted small idle time from active_min when active"
    );

        is( $idle->calculate_idle_stats( $now, 600, {}, { idle_since => $now-60 } )->{idle_since},
        $now-60,
        "Checking that calculate_idle_status did not touch idle_since when still idle"
     );

    is( $idle->calculate_idle_stats( $now, 600, {}, {} )->{idle_since},
        $now-600,
        "Checking that calculate_idle_status calculated initial idle_since using start of idle time"
    );

    is( $idle->calculate_idle_stats( $now, 0, {}, {} )->{idle_min},
        0,
        "Checking that calculate_idle_status calculated 0 minutes of idle time"
    );

    is( $idle->calculate_idle_stats( $now, 600, {}, {} )->{idle_min},
        '10',
        "Checking that calculate_idle_status calculated 10 minutes of idle status"
    );

    is( $idle->calculate_idle_stats( $now, 600, {}, { idle_since => $now-1200 } )->{idle_min},
        10,
        "Checking that calculate_idle_status calculated idle_min using idle time, not idle_since"
     );

}
