#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';
use YAML;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
my $cache_file = "$tempdir/storage.yaml";

use Wubot::Monitor::Check;

ok( my $check = Wubot::Monitor::Check->new( { class      => 'Wubot::Monitor::Plugin::TestCase',
                                              cache_file => $cache_file,
                                          } ),
    "Creating a new check instance"
);

{
    ok( my $results = $check->check( { param1 => 'value1' } ),
        "Calling check() method and passing test config"
    );

    is_deeply( $results,
               { param1 => 'value1' },
               "Checking that check data was written to cache file"
           );

    ok( my $cache = YAML::LoadFile( $cache_file ),
        "Reading check cache file"
    );

    is_deeply( $cache,
               { param1 => 'value1' },
               "Checking that check data was written to cache file"
           );
}

{
    ok( my $results = $check->check( { param2 => 'value2' } ),
        "Calling check() method and passing new config"
    );

    is_deeply( $results,
               { param2 => 'value2' },
               "Checking that check data was written to cache file"
           );

    ok( my $cache = YAML::LoadFile( $cache_file ),
        "Reading check cache file"
    );

    is_deeply( $cache,
               { param1 => 'value1',
                 param2 => 'value2',
             },
               "Checking that check data from both checks was written to cache file"
           );
}


