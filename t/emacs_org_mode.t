#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';
use Test::Differences;
use YAML;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
my $cache_file = "$tempdir/storage.yaml";

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
        ok( my $results = $check->check( { directory => "$ENV{HOME}/org" } ),
            "Calling check() method"
        );

        print YAML::Dump $results;
    }

    {
        ok( my $results = $check->check( { directory => "$ENV{HOME}/org" }, { lastupdate => time } ),
            "Calling check() method with lastupdate set to now"
        );

        print YAML::Dump $results;
    }
}
