#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::More 'no_plan';
use Test::Differences;
use YAML;

Log::Log4perl->easy_init($ERROR);
my $logger = get_logger( 'default' );

use Wubot::Plugin::WebFetch;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

ok( my $check = Wubot::Plugin::WebFetch->new( { class      => 'Wubot::Plugin::OsxIdle',
                                               cache_file => '/dev/null',
                                               key        => 'OsxIdle-testcase',
                                           } ),
    "Creating a new WebFetch check instance"
);

{
    my $config = { url    => 'http://www.google.com/',
                   regexp => { feeling => 'Feeling (\w+)' },
               };

    ok( my $results = $check->check( { config => $config } ),
        "Calling check() method"
    );

    is( $results->{react}->{feeling},
        'Lucky',
        "Checking that 'feeling' regexp matched 'Lucky'"
    );

}

