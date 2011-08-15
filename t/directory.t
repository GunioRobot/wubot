#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';
use Test::Differences;
use YAML;

use Wubot::Logger;
use Wubot::Plugin::Directory;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
my $tempdir2 = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );


ok( my $check = Wubot::Plugin::Directory->new( { class      => 'Wubot::Plugin::Directory',
                                                 cache_file => "$tempdir2/foo",
                                                 key        => 'Directory-testcase',
                                             } ),
    "Creating a new Directory check instance"
);

{
    ok( my $results = $check->check( { config => { path => $tempdir } } ),
        "Calling check() method"
    );

    is_deeply( $results->{react},
               [],
               "Checking that no reaction for empty directory"
           );
}

{
    system( "touch", "$tempdir/foo.txt" );

    ok( my $results = $check->check( { config => { path => $tempdir }, cache => {} } ),
        "Calling check() method"
    );

    is_deeply( $results->{react},
               [ { file => 'foo.txt', subject => "New: foo.txt" } ],
               "Checking that no reaction with one file in directory"
           );

    ok( my $results2 = $check->check( { config => { path => $tempdir }, cache => $results->{cache} } ),
        "Calling check() method"
    );

    is_deeply( $results2->{react},
               [],
               "Checking that no reaction with no change to directory"
           );
}
