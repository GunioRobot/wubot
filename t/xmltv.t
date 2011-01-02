#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::More 'no_plan';
use Test::Differences;
use YAML;

use Wubot::Logger;
my $logger = get_logger( 'default' );

use Wubot::Plugin::XMLTV;

#my $reactor = sub { print YAML::Dump $_[0]; };
my $reactor = sub {};

ok( my $check = Wubot::Plugin::XMLTV->new( { key        => 'XMLTV-testcase',
                                             class      => 'Wubot::Plugin::XMLTV',
                                             cache_file => '/dev/null',
                                             reactor    => $reactor,
                                         } ),
    "Creating a new XMLTV check instance"
);

my $config = { file    => "$ENV{HOME}/.xml_tv",
           };

my $react = $check->check( { config => $config } );


