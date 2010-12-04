#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO);
my $logger = get_logger( 'default' );

use Wubot::Reactor::RRD;

ok( my $rrd = Wubot::Reactor::RRD->new(),
    "Creating a new 'rrd' reactor object"
);

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

my $config = { base_dir  => $tempdir,
               type      => 'GAUGE',
               key       => 'somename',
           };

ok( $rrd->react( { somename => 100, key => 'testcase-key' }, $config ),
    "Calling 'react' with test message"
);

ok( -d "$config->{base_dir}/rrd",
    "Checking that rrd subdirectory was created"
);

ok( -d "$config->{base_dir}/rrd/testcase-key",
    "Checking that testcase-key subdirectory was created"
);

ok( -r "$config->{base_dir}/rrd/testcase-key/somename.rrd",
    "Checking that rrd file was created using key field"
);

ok( -d "$config->{base_dir}/graphs",
    "Checking that graph directory was created"
);

ok( -d "$config->{base_dir}/graphs/testcase-key",
    "Checking that graph subdirectory testcase-key was created"
);

ok( -r "$config->{base_dir}/graphs/testcase-key/somename-daily.png",
    "Checking that png was created use key field as basename"
);

sleep 1;

ok( $rrd->react( { somename => 200.5, key => 'testcase-key' }, $config ),
    "Calling 'react' with test message"
);
