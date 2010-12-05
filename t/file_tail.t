#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::Exception;
use Test::More 'no_plan';
use YAML;

Log::Log4perl->easy_init($ERROR);

use Wubot::Plugin::FileTail;

my $init = { key        => 'FileTail-testcase',
             class      => 'Wubot::Plugin::FileTail',
             cache_file => '/dev/null',
         };

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

{
    ok( my $tail = Wubot::Plugin::FileTail->new( $init ),
        "Creating new file tail object"
    );

    my $path = "$tempdir/file0.log";

    throws_ok( sub { $tail->check( { config => { path => $path } } ) },
               qr/path not readable/,
               "Calling reaction on a file that does not exist"
           );
}


$| = 1;

{
    ok( my $tail = Wubot::Plugin::FileTail->new( $init ),
        "Creating new file tail object"
    );

    my $path = "$tempdir/file1.log";

    open(my $fh, ">", $path)
        or die "Couldn't open $path for writing: $!\n";
    select $fh;
    $|=1;
    select STDOUT;
    $| = 1;

    print $fh "line1\n";
    print $fh "line2\n";

    ok( ! $tail->check( { config => { path => $path } } ),
        "Calling reaction on file that exists but is empty"
    );

    print $fh "line3\n";
    print $fh "line4\n";
    close $fh or die "Error closing file: $!\n";

    ok( ! $tail->check( { config => { path => $path } } ),
        "Checking that check returns failure on first read attempt"
    );

    is( $tail->check( { config => { path => $path } } )->{react}->[0]->{subject},
        'line3',
        "Calling reaction read 'line3'"
    );

    is( $tail->check( { config => { path => $path } } )->{react}->[0]->{subject},
        'line4',
        "Calling reaction read 'line4'"
    );

}


