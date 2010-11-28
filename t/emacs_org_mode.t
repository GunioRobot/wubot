#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::More 'no_plan';
use Test::Differences;
use YAML;

Log::Log4perl->easy_init($WARN);
my $logger = get_logger( 'default' );

use Wubot::Plugin::EmacsOrgMode;
use Wubot::Reactor;

my $reactor = Wubot::Reactor->new();


my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
my $cache_file = "$tempdir/storage.yaml";

create_file1( $tempdir );
create_file2( $tempdir );
create_file3( $tempdir );
create_file4( $tempdir );
create_file5( $tempdir );


{

    my $reaction = [];
    ok( my $check = Wubot::Plugin::EmacsOrgMode->new( { key        => 'EmacsOrgMode-testcase',
                                                        class      => 'Wubot::Plugin::EmacsOrgMode',
                                                        cache_file => $cache_file,
                                                        reactor    => $reactor,
                                                    } ),
        "Creating a new Emacs Org Mode check instance"
    );

    {
        ok( my $results = $check->check( { config => { directory => $tempdir } } ),
            "Calling check() method again, no changes"
        );

        is( $results->{react}->[0]->{name},
            'file1',
            "Checking name of the first file"
        );

        is( $results->{react}->[1]->{name},
            'file2',
            "Checking name of the second file"
        );

        is( $results->{react}->[2]->{name},
            'file3',
            "Checking name of the third file"
        );

        is( $results->{react}->[3]->{name},
            'file4',
            "Checking name of the third file"
        );

        is( $results->{react}->[0]->{done},
            1,
            "Checking that no incomplete tasks found on file1"
        );

        is( $results->{react}->[1]->{done},
            0,
            "Checking that incomplete tasks found on file2"
        );

        is( $results->{react}->[2]->{done},
            1,
            "Checking that no incomplete tasks found on file3"
        );

        is( $results->{react}->[3]->{done},
            1,
            "Checking that no incomplete tasks found on file4"
        );

        is( $results->{react}->[0]->{color},
            '',
            "Checking that page with no incomplete tasks and no meta color defaults to no color"
        );

        is( $results->{react}->[1]->{color},
            'blue',
            "Checking that page with incomplete tasks defaults to color 'blue'"
        );

        is( $results->{react}->[2]->{color},
            '',
            "Checking that page with complete tasks defaults to no color"
        );

        is( $results->{react}->[3]->{color},
            'asdf',
            "Checking that page with meta color defined gets meta color"
        );

        is( $results->{react}->[4]->{color},
            'qwer',
            "Checking that page with meta color defined gets meta color"
        );

        ok( my $results2 = $check->check( { config => { directory => $tempdir },
                                            cache  => $results->{cache}         } ),
            "Calling check() method with lastupdate set to now"
        );

        is_deeply( $results2->{react},
                   [],
                   "Checking that results were blank on the second scan"
               );
    }
}



sub create_file1 {
    my ( $directory ) = @_;

    my $path = "$directory/file1.org";

    open(my $fh, ">", $path)
        or die "Couldn't open $path for writing: $!\n";
    print $fh <<"END_FILE1";

* Test Case 1

  - a 1
    - a 1.2
    - a 1.3
  - b 1
  - c 1
  - color: yellow
    - not in meta block

END_FILE1

    close $fh or die "Error closing file: $!\n";
}

sub create_file2 {
    my ( $directory ) = @_;

    my $path = "$directory/file2.org";

    open(my $fh, ">", $path)
        or die "Couldn't open $path for writing: $!\n";
    print $fh <<"END_FILE1";

* Some Tasks

  - [ ] x task
    - [ ] x.1 subtask
    - [ ] x.2 subtask

  - [X] y task
    - [X] y.1 subtask done


END_FILE1

    close $fh or die "Error closing file: $!\n";
}

sub create_file3 {
    my ( $directory ) = @_;

    my $path = "$directory/file3.org";

    open(my $fh, ">", $path)
        or die "Couldn't open $path for writing: $!\n";
    print $fh <<"END_FILE1";

* Some Tasks

  - [X] x task
    - [X] x.1 subtask
    - [X] x.2 subtask

  - [X] y task
    - [X] y.1 subtask done


END_FILE1

    close $fh or die "Error closing file: $!\n";
}

sub create_file4 {
    my ( $directory ) = @_;

    my $path = "$directory/file4.org";

    open(my $fh, ">", $path)
        or die "Couldn't open $path for writing: $!\n";
    print $fh <<"END_FILE1";

* Meta

  - color: asdf
    - in meta block

  - due: 2020/01/02 1pm


END_FILE1

    close $fh or die "Error closing file: $!\n";
}


sub create_file5 {
    my ( $directory ) = @_;

    my $path = "$directory/file5.org";

    open(my $fh, ">", $path)
        or die "Couldn't open $path for writing: $!\n";
    print $fh <<"END_FILE1";

* Foo

  - x
  - y
  - z

* Meta

  - color: qwer


END_FILE1

    close $fh or die "Error closing file: $!\n";
}

