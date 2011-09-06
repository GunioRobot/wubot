#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';
use YAML;

use App::Wubot::Logger;
use App::Wubot::Plugin::WebFetch;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

ok( my $check = App::Wubot::Plugin::WebFetch->new( { class      => 'App::Wubot::Plugin::OsxIdle',
                                               cache_file => '/dev/null',
                                               key        => 'OsxIdle-testcase',
                                           } ),
    "Creating a new WebFetch check instance"
);

{
    my $config = { url    => 'http://www.google.com/',
               };

    ok( my $results = $check->check( { config => $config } ),
        "Calling check() method"
    );

    like( $results->{react}->{content},
          qr/Feeling Lucky/,
          "Checking that content contains 'Feeling Lucky'"
         );

}


{
    my $config = { url    => 'http://www.google.com/',
                   field  => 'foo'
               };

    ok( my $results = $check->check( { config => $config } ),
        "Calling check() method"
    );

    like( $results->{react}->{foo},
          qr/Feeling Lucky/,
          "Checking that 'foo' field contains 'Feeling Lucky'"
         );

}

