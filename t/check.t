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
    my @react;

    my $tempdir1 = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    ok( my $check = Wubot::Check->new( { class             => 'Wubot::Plugin::TestCase',
                                         cache_file        => $cache_file,
                                         key               => 'TestCase-testcase',
                                         reactor_queue_dir => $tempdir1,
                                     } ),
        "Creating a new check instance"
    );

    ok( my $results = $check->check( { param2 => 'value2', param3 => 'value3', tags => 'testcase' } ),
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
        "Checking that param2 set in result hash"
    );
    is( $results->{react}->[0]->{param3},
        'value3',
        "Checking that param3 set in result hash"
    );
    is( $results->{react}->[0]->{tags},
        'testcase',
        "Checking that configured 'tag' set in result hash"
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

    my $queue_contents = $check->reactor_queue->get( $tempdir1 );
    is( $queue_contents->{param2},
        "value2",
        "Checking that param1 set to value1 in queue"
    );
    is( $queue_contents->{param3},
        "value3",
        "Checking that param1 set to value1 in queue"
    );
    is( $queue_contents->{tags},
        "testcase",
        "Checking that param1 set to value1 in queue"
    );
    is( $queue_contents->{key},
        "TestCase-testcase",
        "Checking key from queue contents"
    );

    # is( $queue_contents->{checksum},
    #     "d63d6fe72528843017fb99c108239483",
    #     "Checking key from queue contents"
    # );

}


