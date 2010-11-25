#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';
use Test::Differences;
use YAML;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
my $cache_file = "$tempdir/storage.yaml";

create_file1( $tempdir );
create_file2( $tempdir );
create_file3( $tempdir );
create_file4( $tempdir );
create_file5( $tempdir );

use Wubot::Check;

{

    my $reaction = [];
    ok( my $check = Wubot::Check->new( { class      => 'Wubot::Plugin::EmacsOrgMode',
                                         cache_file => $cache_file,
                                         reactor    => sub { push @{ $reaction }, $_[0] },
                                         key        => 'EmacsOrgMode-testcase',
                                     } ),
        "Creating a new Emacs Org Mode check instance"
    );

    {
        ok( my $results = $check->check( { directory => $tempdir } ),
            "Calling check() method again, no changes"
        );

        is( $results->[0]->{name},
            'file1',
            "Checking name of the first file"
        );

        is( $results->[1]->{name},
            'file2',
            "Checking name of the second file"
        );

        is( $results->[2]->{name},
            'file3',
            "Checking name of the third file"
        );

        is( $results->[3]->{name},
            'file4',
            "Checking name of the third file"
        );

        is( $results->[0]->{done},
            1,
            "Checking that no incomplete tasks found on file1"
        );

        is( $results->[1]->{done},
            0,
            "Checking that incomplete tasks found on file2"
        );

        is( $results->[2]->{done},
            1,
            "Checking that no incomplete tasks found on file3"
        );

        is( $results->[3]->{done},
            1,
            "Checking that no incomplete tasks found on file4"
        );

        is( $results->[1]->{color},
            undef,
            "Checking that no meta color found on file1 with no color defined"
        );

        is( $results->[0]->{color},
            undef,
            "Checking that no meta color found on file3 with color in non-meta block"
        );

        is( $results->[3]->{color},
            'yellow',
            "Checking that meta color found on file4"
        );

        is( $results->[4]->{color},
            'yellow',
            "Checking that meta color found on file5"
        );
    }

    {
        ok( my $results = $check->check( { directory => $tempdir }, { lastupdate => time } ),
            "Calling check() method with lastupdate set to now"
        );

        is_deeply( $results,
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

  - color: yellow
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

  - color: yellow


END_FILE1

    close $fh or die "Error closing file: $!\n";
}

