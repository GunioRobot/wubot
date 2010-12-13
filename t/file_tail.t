#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::Exception;
use Test::More 'no_plan';
use YAML;

Log::Log4perl->easy_init($WARN);

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
    my $path = "$tempdir/file1.log";

    system( "echo line0 >> $path" );
    system( "echo line0 >> $path" );

    ok( my $tail = Wubot::Plugin::FileTail->new( $init ),
        "Creating new file tail object"
    );

    ok( ! $tail->check( { config => { path => $path } } ),
        "Calling reaction on file that exists but has had no writes since open"
    );

    system( "echo line1 >> $path" );
    system( "echo line2 >> $path" );

    my $results1 = $tail->check( { config => { path => $path } } );

    is( $results1->{react}->[0]->{subject},
        'line1',
        "Calling reaction read 'line1'"
    );

    is( $results1->{react}->[1]->{subject},
        'line2',
        "Calling reaction read 'line2'"
    );

    ok( ! $tail->check( { config => { path => $path } } ),
        "Calling reaction after all lines read"
    );

    system( "echo line3 >> $path" );
    system( "echo line4 >> $path" );

    my $results1 = $tail->check( { config => { path => $path } } );

    is( $results1->{react}->[0]->{subject},
        'line3',
        "Calling reaction read 'line3'"
    );

    is( $results1->{react}->[1]->{subject},
        'line4',
        "Calling reaction read 'line4'"
    );

    ok( ! $tail->check( { config => { path => $path } } ),
        "Calling reaction after all lines read"
    );

    system( "echo line5 > $path" );
    system( "echo line6 >> $path" );

    my $results1 = $tail->check( { config => { path => $path } } );

    is( $results1->{react}->[0]->{subject},
        'line5',
        "Calling reaction read 'line5'"
    );

    is( $results1->{react}->[1]->{subject},
        'line6',
        "Calling reaction read 'line6'"
    );

    ok( ! $tail->check( { config => { path => $path } } ),
        "Calling reaction after no more writes"
    );

    sleep 1;
    unlink( $path );
    system( "echo line6 >> $path" );
    system( "echo line7 >> $path" );

    my $results1 = $tail->check( { config => { path => $path } } );

    is( $results1->{react}->[0]->{subject},
        'line6',
        "Calling reaction read 'line6'"
    );

    is( $results1->{react}->[1]->{subject},
        'line7',
        "Calling reaction read 'line7'"
    );

    ok( ! $tail->check( { config => { path => $path } } ),
        "Calling reaction after no more writes"
    );

    sleep 1; # mv file and re-create
    system( "mv $path $path.old" );
    system( "echo line8 > $path" );
    system( "echo line9 >> $path" );

    my $results1 = $tail->check( { config => { path => $path } } );

    is( $results1->{react}->[0]->{subject},
        'line8',
        "Calling reaction read 'line8'"
    );

    is( $results1->{react}->[1]->{subject},
        'line9',
        "Calling reaction read 'line9'"
    );

    ok( ! $tail->check( { config => { path => $path } } ),
        "Calling reaction after no more writes"
    );
}
