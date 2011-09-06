#!/perl
use strict;

use Capture::Tiny qw/capture/;
use File::Temp qw/ tempdir /;
use Test::Exception;
use Test::More 'no_plan';
use YAML;

use App::Wubot::Logger;
use App::Wubot::Util::Tail;

$| = 1;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

{
    my $path = "$tempdir/file1.log";

    system( "echo line0 >> $path" );
    system( "echo line0 >> $path" );

    my @lines;
    my @warn;

    ok( my $tail = App::Wubot::Util::Tail->new( { path           => $path,
                                             callback       => sub { push @lines, @_ },
                                             reset_callback => sub { push @warn,  @_ },
                                         } ),
        "Creating new file tail object"
    );

    {
        is( $tail->get_lines(),
            0,
            "Calling get_lines() on file that exists but has had no writes since open"
        );
    }

    system( "echo line1 >> $path" );
    system( "echo line2 >> $path" );

    {
        is( $tail->get_lines(),
            2,
            "Got 2 new lines from file"
        );

        is_deeply( \@lines,
                   [ 'line1', 'line2' ],
                   "Checking lines read from file"
               );
        undef @lines;

        is( $tail->get_lines(),
            0,
            "Got 0 new lines"
        );

    }

    system( "echo line3 >> $path" );
    system( "echo line4 >> $path" );

    {
        is( $tail->get_lines(),
            2,
            "Got 2 new lines from file"
        );

        is_deeply( \@lines,
                   [ 'line3', 'line4' ],
                   "Getting 2 more lines from file"
               );
        undef @lines;

        is( $tail->get_lines(),
            0,
            "Got 0 new lines"
        );

    }

    system( "echo line5 > $path" );
    system( "echo line6 >> $path" );
    system( "echo line7 >> $path" );

    {
        is( $tail->get_lines(),
            3,
            "Got 3 new lines from file"
        );

        like( $warn[0],
              qr/file was truncated: $path/,
              "Checking for 'file was truncated' warning"
          );
        undef @warn;

        is_deeply( \@lines,
                   [ 'line5', 'line6', 'line7' ],
                   "Getting 2 more lines from file after truncating"
               );

        is( $tail->get_lines(),
            0,
            "Got 0 new lines"
        );

        undef @lines;
    }

    sleep 1;
    unlink( $path );
    system( "echo line8 >> $path" );
    system( "echo line9 >> $path" );

    {
        is( $tail->get_lines(),
            2,
            "Got 2 new lines from file"
        );

        like( $warn[0],
              qr/file was renamed: $path/,
              "Checking for 'file was renamed' warning"
          );
        undef @warn;

        is_deeply( \@lines,
                   [ 'line8', 'line9' ],
                   "Getting 2 more lines from file after unlinking"
               );
        undef @lines;

        is( $tail->get_lines(),
            0,
            "Got 0 new lines"
        );

    }

    sleep 1; # mv file and re-create
    system( "mv $path $path.old" );
    system( "echo line10 > $path" );
    system( "echo line11 >> $path" );

    {
        is( $tail->get_lines(),
            2,
            "Got 2 new lines from file"
        );

        like( $warn[0],
              qr/file was renamed: $path/,
              "Checking for 'file was renamed' warning"
          );
        undef @warn;

        is_deeply( \@lines,
                   [ 'line10', 'line11' ],
                   "Getting 2 more lines from file after renaming"
               );
        undef @lines;

        is( $tail->get_lines(),
            0,
            "Got 0 new lines"
        );

    }

    sleep 1;
    system( "echo line12 > $path" );
    system( "echo line13 >> $path" );

    {
        is( $tail->get_lines(),
            2,
            "Got 2 new lines from file"
        );

        like( $warn[0],
              qr/file was renamed: $path/,
              "checking for 'file was renamed' after truncating file to the same length"
          );
        undef @warn;

        is_deeply( \@lines,
                   [ 'line12', 'line13' ],
                   "Getting 2 more lines from file after truncating to same length"
               );
        undef @lines;

        is( $tail->get_lines(),
            0,
            "Got 0 new lines"
        );

    }

    sleep 1;
    system( "echo line14 > $path" );
    system( "echo line15 >> $path" );
    system( "echo line16 >> $path" );

    {
        is( $tail->get_lines(),
            1,
            "Got only 1 new lines from file"
        );

        is( scalar @warn,
            0,
            "known bug - file truncated, then more lines written than last read"
        );

        is_deeply( \@lines,
                   [ 'line16' ],
                   "Got only one more line from file after truncating and writing to longer length"
               );
        undef @lines;

        is( $tail->get_lines(),
            0,
            "Got 0 new lines"
        );

    }

    # refresh interval
    sleep 1;
    system( "echo line15 > $path" );

    {
        # setting count back to 0
        $tail->count(   0 );
        $tail->refresh( 2 );

        is( $tail->get_lines(),
            0,
            "Got 0 new lines"
        );

        is( $tail->get_lines(),
            1,
            "Got 1 new lines from file"
        );

        like( $warn[0],
              qr/file was truncated: $path/,
              "Checking for 'file was truncated' warning"
          );
        undef @warn;

        is_deeply( \@lines,
                   [ 'line15' ],
                   "Getting 2 more lines after refresh"
               );
        undef @lines;

        is( $tail->get_lines(),
            0,
            "Got 0 new lines"
        );

    }
}


{
    my $path = "$tempdir/file2.log";

    system( "touch $path" );

    my $position;

    {
        my @lines;

        ok( my $tail = App::Wubot::Util::Tail->new( { path           => $path,
                                                 callback       => sub { push @lines, @_ },
                                                 reset_callback => sub { return },
                                             } ),
            "Creating new file tail object"
        );

        is( $tail->get_lines(),
            0,
            "Calling get_lines() on file that exists but has had no writes since open"
        );

        system( "echo line1 >> $path" );
        system( "echo line2 >> $path" );

        is( $tail->get_lines(),
            2,
            "Got 2 new lines from file"
        );
        is_deeply( \@lines,
                   [ 'line1', 'line2' ],
                   "Checking lines read from file"
               );

        $position = $tail->position;

        undef $tail;
    }

    system( "echo line3 >> $path" );
    system( "echo line4 >> $path" );

    {
        my @lines;

        ok( my $tail = App::Wubot::Util::Tail->new( { path           => $path,
                                                 callback       => sub { push @lines, @_ },
                                                 reset_callback => sub { return },
                                                 position       => $position,
                                             } ),
            "Creating new file tail object"
        );

        is( $tail->get_lines(),
            2,
            "Calling get_lines() on file that was updated before second App::Wubot::Util::Tail object was created"
        );

        is_deeply( \@lines,
                   [ 'line3', 'line4' ],
                   "Checking lines read from file"
               );
    }

}



{
    my $path = "$tempdir/file3.log";

    system( "echo line1 >> $path" );
    system( "echo line2 >> $path" );

    my @lines;
    my @warn;

    ok( my $tail = App::Wubot::Util::Tail->new( { path           => $path,
                                             callback       => sub { push @lines, @_ },
                                             reset_callback => sub { push @warn,  @_ },
                                             position       => 1024,
                                         } ),
        "Creating new file tail object"
    );

    is( $tail->get_lines(),
        2,
        "Calling get_lines() on file where last position is greater than current end of file",
    );

    is_deeply( \@lines,
               [ 'line1', 'line2' ],
               "Checking lines read from file"
           );

    like( $warn[0],
          qr/file was truncated: $path/,
          "Checking for 'file was truncated' warning"
      );
}
