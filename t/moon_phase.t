#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::More 'no_plan';
use Test::Differences;
use YAML;

Log::Log4perl->easy_init($ERROR);
my $logger = get_logger( 'default' );

use Wubot::Plugin::MoonPhase;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );


ok( my $check = Wubot::Plugin::MoonPhase->new( { class      => 'Wubot::Plugin::OsxIdle',
                                            cache_file => '/dev/null',
                                            key        => 'OsxIdle-testcase',
                                        } ),
    "Creating a new MoonPhase check instance"
);

ok( my $results = $check->check( ),
    "Calling check() method"
);

ok( $results->{react}->{age},
    "Checking that moon age is set"
);

ok( $results->{react}->{phase} && $results->{react}->{phase} > 0 && $results->{react}->{phase} < 1,
    "Checking 'phase' is set to a valid value"
);

#print YAML::Dump $results;
