#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';
use YAML;

use Wubot::Logger;
use Wubot::Plugin::Pulse;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

ok( my $check = Wubot::Plugin::Pulse->new( { class      => 'Wubot::Plugin::Pulse',
                                            cache_file => "$tempdir/Pulse.cache.yaml",
                                            key        => 'Pulse-navi',
                                        } ),
    "Creating a new Pulse check instance"
);

{
    ok( my $results_h = $check->check( ),
        "Calling check() method for first check"
    );

    is( scalar @{ $results_h->{react} },
        1,
        "Checking that only one message was sent"
    );

    is( $results_h->{react}->[0]->{age},
        0,
        "Checking that the 'age' field on the message was set to 0, indicating it is now"
    );
}

{
    my $time = time - 300;

    ok( my $results_h = $check->check( { cache => { lastupdate => $time } } ),
        "Calling check() method after 5 minutes of no checks"
    );

    is( scalar @{ $results_h->{react} },
        5,
        "Checking that 5 messages were sent"
    );

    is( $results_h->{react}->[0]->{age},
        4,
        "Checking that the 'age' field on the oldest message is 4"
    );

    is( $results_h->{react}->[1]->{age},
        3,
        "Checking that the 'age' field on the 2nd message is 3"
    );

    is( $results_h->{react}->[2]->{age},
        2,
        "Checking that the 'age' field on the 3rd message is 2"
    );

    is( $results_h->{react}->[3]->{age},
        1,
        "Checking that the 'age' field on the 4th message is 1"
    );

    is( $results_h->{react}->[4]->{age},
        0,
        "Checking that the 'age' field on the message was set to 0, indicating it is now"
    );
}


{
    my $time = time;

    ok( my $results_h = $check->check( { cache => { lastupdate => $time } } ),
        "Calling check() method after 0 minutes of no checks"
    );

    is( scalar @{ $results_h->{react} },
        0,
        "Checking that 0 messages were sent when pulse ran again in the same second"
    );
}


{
    my $time = time - 30;

    ok( my $results_h = $check->check( { cache => { lastupdate => $time } } ),
        "Calling check() method after less than 1 minute since last check"
    );

    is( scalar @{ $results_h->{react} },
        0,
        "Checking that 0 messages were sent when pulse ran again in the same second"
    );
}


{
    my $time = time - 90;

    ok( my $results_h = $check->check( { cache => { lastupdate => $time } } ),
        "Calling check() method 90 seconds since last check"
    );

    is( scalar @{ $results_h->{react} },
        1,
        "Checking that 1 messages were sent when pulse ran again in 90 seconds"
    );

    is( $results_h->{react}->[0]->{age},
        0,
        "Checking that the 'age' field on the message was set to 0, indicating it is now"
    );
}

