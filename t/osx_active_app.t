#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';
use Test::Differences;
use YAML;

use Wubot::Logger;
use Wubot::Plugin::OsxActiveApp;

{
    ok( my $check = Wubot::Plugin::OsxActiveApp->new( { class      => 'Wubot::Plugin::OsxActiveApp',
                                                        cache_file => '/dev/null',
                                                        key        => 'OsxActiveApp-test',
                                               } ),
        "Creating a new OSX Active App check instance"
    );

    ok( my $results = $check->check( {} ),
        "Calling check() method"
    );

    ok( $results->{react}->{application},
        "Checking that an active application was found: $results->{react}->{application}"
    );

}
