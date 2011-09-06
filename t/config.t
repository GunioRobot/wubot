#!/perl
use strict;

use Test::More 'no_plan';

use App::Wubot::Logger;
use App::Wubot::Config;

ok( my $config = App::Wubot::Config->new( { root => 't/config' } ),
    "Creating new App::Wubot::Config object"
);

is_deeply( [ $config->get_plugins() ],
           [ "TestCase-test1", "TestCase-test2", "TestCase-test3" ],
           "Getting list of configured plugins"
       );

is_deeply( $config->get_plugin_config( 'TestCase-test1' ),
           {
               plugin => 'App::Wubot::Plugin::TestCase',
               param1 => 'value1',
               hash1  => { key1 => 'value1', key2 => 'value2' },
           },
           "Checking that test case 1 config read"
       );

is( $config->get_plugin_config( 'TestCase-test1', 'param1' ),
    'value1',
    "Checking that test1 data for param1 was read"
);

is_deeply( $config->get_plugin_config( 'TestCase-test1', 'hash1' ),
           { key1 => 'value1', key2 => 'value2' },
           "Checking that test1 data for hash1 was read"
       );

ok( $config->get_plugin_config( 'TestCase-test2' ),
    "Checking that test case 2 config read"
);

ok( $config->get_plugin_config( 'TestCase-test3' ),
    "Checking that test case 3 config read"
);
