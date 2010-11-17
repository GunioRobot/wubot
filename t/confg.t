#!/perl
use strict;

use Test::More 'no_plan';

use Wubot::Monitor::Config;

ok( my $config = Wubot::Monitor::Config->new( { root => 't/config' } ),
    "Creating new Wubot::Monitor::Config object"
);

is_deeply( [ $config->get_monitors() ],
           [ "TestCase-test1", "TestCase-test2", "TestCase-test3" ],
           "Getting list of configured monitors"
       );

is_deeply( $config->get_monitor_config( 'TestCase-test1' ),
           {
               class => 'Wubot::Monitor::TestCase',
               param1 => 'value1',
               hash1 => { key1 => 'value1', key2 => 'value2' },
           },
           "Checking that test case 1 config read"
       );

is( $config->get_monitor_config( 'TestCase-test1', 'param1' ),
    'value1',
    "Checking that test1 data for param1 was read"
);

is_deeply( $config->get_monitor_config( 'TestCase-test1', 'hash1' ),
           { key1 => 'value1', key2 => 'value2' },
           "Checking that test1 data for hash1 was read"
       );

ok( $config->get_monitor_config( 'TestCase-test2' ),
    "Checking that test case 2 config read"
);

ok( $config->get_monitor_config( 'TestCase-test3' ),
    "Checking that test case 3 config read"
);
