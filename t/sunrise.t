#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::More 'no_plan';
use Test::Differences;
use YAML;

Log::Log4perl->easy_init($ERROR);
my $logger = get_logger( 'default' );

use Wubot::Plugin::SunRise;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

ok( my $check = Wubot::Plugin::SunRise->new( { class      => 'Wubot::Plugin::OsxIdle',
                                               cache_file => '/dev/null',
                                               key        => 'OsxIdle-testcase',
                                           } ),
    "Creating a new SunRise check instance"
);

my $config = { longitude => -122.6362492,
               latitude  => 47.5403732,
           };

my $cache = {};

{
    ok( my $results = $check->check( { config => $config } ),
        "Calling check() method"
    );

    $cache = $results->{cache};

    ok( $results->{react}->{next_utime} > time,
        "Checking that next utime is in the future"
    );

    ok( $results->{react}->{next_until} > 0,
        "Checking that next_until is positive"
    );

    ok( ! $results->{react}->{cache_remaining},
        "Cache not used on first check"
    );

}


# {
#     ok( my $results = $check->check( { config => $config, cache => $cache } ),
#         "Calling check() method"
#     );

#     ok( $results->{react}->{next_utime} > time,
#         "Checking that next utime is in the future"
#     );

#     ok( $results->{react}->{next_until} > 0,
#         "Checking that next_until is positive"
#     );

#     ok( $results->{react}->{cache_remaining},
#         "Cache used on second check"
#     );

#     print YAML::Dump $results;
# }

