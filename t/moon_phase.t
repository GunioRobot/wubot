#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Test::More;

eval "use Astro::MoonPhase";

if ( $@ ) {
    plan skip_all => 'Astro::MoonPahse required for this plugin';
}
else {

    plan 'no_plan';

    require Wubot::Logger;
    require Wubot::Plugin::MoonPhase;

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

}
