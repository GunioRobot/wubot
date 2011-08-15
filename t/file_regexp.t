#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';
use YAML;

use Wubot::Logger;
use Wubot::Plugin::FileRegexp;

my $init = { key        => 'FileRegexp-testcase',
             class      => 'Wubot::Plugin::FileRegexp',
             cache_file => '/dev/null',
         };

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

$| = 1;

{
    my $path = "$tempdir/file1.log";

    ok( my $tail = Wubot::Plugin::FileRegexp->new( $init ),
        "Creating new file tail object"
    );

    ok( ! $tail->init( { config => { path   => $path,
                                     regexp => { testall => 'test',
                                                 testone => 'test1',
                                             },
                                 } } ),
        "Initializing tail plugin"
    );

    system( "touch $path" );

    ok( $tail->check(),
        "No lines on initial check"
    );

    system( "echo test1 match >> $path" );
    system( "echo test2 match >> $path" );

    ok( my $results = $tail->check(),
        "Calling check() now that a couple of lines were added"
    );

    is( $results->{react}->{testall},
        2,
        "Checking that two lines matched 'test' regexp"
    );

    is( $results->{react}->{testone},
        1,
        "Checking that one lines matched 'test1' regexp"
    );

    is( $results->{cache}->{position},
        24,
        "Checking that current file position is 24"
    );

    is( $tail->check()->{cache}->{position},
        24,
        "Checking that position stays at 24 after no new lines read"
    );

    system( "echo test3 match >> $path" );
    system( "echo test4 match >> $path" );

    is( $tail->check()->{cache}->{position},
        48,
        "Checking that position advanced to 48 after adding two more lines"
    );

}
