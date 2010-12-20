#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::More 'no_plan';
use Test::Differences;
use YAML;

Log::Log4perl->easy_init($ERROR);
my $logger = get_logger( 'default' );

use Wubot::Plugin::Arp;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
my $cache_file = "$tempdir/storage.yaml";


{
    ok( my $check = Wubot::Plugin::Arp->new( { class      => 'Wubot::Plugin::Arp',
                                               cache_file => $cache_file,
                                               key        => 'Arp-testcase',
                                           } ),
        "Creating a new OSX Idle check instance"
    );

    ok( my $results = $check->check( {} ),
        "Calling check() method"
    );

    for my $react ( @{ $results->{react} } ) {
        ok( $react->{ip},
            "Checking that entry in arp table has an ip address"
        );
        ok( $react->{mac},
            "Checking that entry in arp table has a mac address"
        );
        ok( $react->{name},
            "Checking that entry in arp table has a name"
        );
    }

}
