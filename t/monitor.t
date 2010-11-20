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
    ok( my $check = Wubot::Check->new( { class      => 'Wubot::Plugin::TestCase',
                                                  cache_file => $cache_file,
                                                  reactor    => sub { push @{ $reaction }, $_[0] },
                                              } ),
        "Creating a new check instance"
    );

    ok( my $results = $check->check( { param1 => 'value1' } ),
        "Calling check() method and passing test config"
    );

    eq_or_diff( $results,
                [ { param1 => 'value1' } ],
                "Checking that check data was written to cache file"
            );

    eq_or_diff( $reaction,
                [ { param1 => 'value1' } ],
                "Checking that check data was written to cache file"
            );

    ok( my $cache = YAML::LoadFile( $cache_file ),
        "Reading check cache file"
    );

    eq_or_diff( $cache,
                {
                    param1 => 'value1' },
                "Checking that check data was written to cache file"
            );
}

{
    my $reaction = [];
    ok( my $check = Wubot::Check->new( { class      => 'Wubot::Plugin::TestCase',
                                                  cache_file => $cache_file,
                                                  reactor    => sub { push @{ $reaction }, $_[0] },
                                              } ),
        "Creating a new check instance"
    );

    ok( my $results = $check->check( { param2 => 'value2', param3 => 'value3' } ),
        "Calling check() method and passing new config"
    );

    eq_or_diff( $results,
                [ { param2 => 'value2' },
                  { param3 => 'value3' },
              ],
                "Checking that check data was written to cache file"
            );

    eq_or_diff( $reaction,
                [ { param2 => 'value2' },
                  { param3 => 'value3' },
              ],
                "Checking that check data was written to cache file"
            );

    ok( my $cache = YAML::LoadFile( $cache_file ),
        "Reading check cache file"
    );

    eq_or_diff( $cache,
                { param1 => 'value1',
                  param2 => 'value2',
                  param3 => 'value3',
              },
                "Checking that check data from both checks was written to cache file"
            );
}


