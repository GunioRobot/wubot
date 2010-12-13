#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::More 'no_plan';
use Test::Differences;
use YAML;

Log::Log4perl->easy_init($INFO);
my $logger = get_logger( 'default' );

use Wubot::Check;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
my $cache_file = "$tempdir/storage.yaml";

{
    ok( my $check = Wubot::Check->new( { class      => 'Wubot::Plugin::TestCase',
                                         cache_file => $cache_file,
                                         key        => 'TestCase-testcase',
                                     } ),
        "Creating a new check instance"
    );

    ok( my $results = $check->check( { param1 => 'value1' } ),
        "Calling check() method and passing test config"
    );

    is( $results->{cache}->{param1},
        'value1',
        "Checking that check param set in cache data"
    );

    is( $results->{react}->[0]->{param1},
        'value1',
        "Checking that check param set in result data"
    );

    ok( my $cache = YAML::LoadFile( $cache_file ),
        "Reading check cache file"
    );

    is( $cache->{param1},
        'value1',
        "Checking that check data was written to cache file"
    );
}

{
    ok( my $check = Wubot::Check->new( { class      => 'Wubot::Plugin::TestCase',
                                         cache_file => $cache_file,
                                         key        => 'TestCase-testcase',
                                     } ),
        "Creating a new check instance"
    );

    ok( my $results = $check->check( { param2 => 'value2', param3 => 'value3' } ),
        "Calling check() method and passing new config"
    );

    is( $results->{cache}->{param1},
        'value1',
        "Checking that param1 is still set in cache data"
    );

    is( $results->{cache}->{param2},
        'value2',
        "Checking that param2 set in cache data"
    );

    is( $results->{cache}->{param3},
        'value3',
        "Checking that param3 set in cache data"
    );

    is( $results->{react}->[0]->{param2},
        'value2',
        "Checking that param2 set in first result hash"
    );

    is( $results->{react}->[1]->{param3},
        'value3',
        "Checking that param3 set in second result hash"
    );

    ok( my $cache = YAML::LoadFile( $cache_file ),
        "Reading check cache file"
    );

    is( $cache->{param1},
         'value1',
         'Checking that param1 still exists in cache file'
     );
    is( $cache->{param2},
         'value2',
         'Checking that param2 exists in cache file'
     );
    is( $cache->{param3},
         'value3',
         'Checking that param3 exists in cache file'
     );


}


