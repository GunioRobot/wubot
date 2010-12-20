#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Sys::Hostname;
use Test::Exception;
use Test::More 'no_plan';
use YAML;

Log::Log4perl->easy_init($WARN);

use Wubot::LocalMessageStore;
use Wubot::Plugin::RemoteQueue;

my $init = { key        => 'RemoteQueue-testcase',
             class      => 'Wubot::Plugin::RemoteQueue',
             cache_file => '/dev/null',
         };

ok( my $remote_queue = Wubot::Plugin::RemoteQueue->new( $init ),
    "Creating new file tail object"
);

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

my $message = { foo        => 1,
                checksum   => 1234,
                key        => 'testcase',
                lastupdate => time,
                hostname   => hostname(),
            };

# setup - add two message to local store
{


    ok( my $messenger = Wubot::LocalMessageStore->new(),
        "Creating a new messenger"
    );

    ok( $messenger->store( { %{ $message }, count => 1 }, $tempdir ),
        "Storing message"
    );

    ok( $messenger->store( { %{ $message }, count => 2 }, $tempdir ),
        "Storing message"
    );
}

my $config  = { host => 'localhost',
                path => $tempdir,
                perl => '/usr/local/bin/perl',
            };

{
    my $results = $remote_queue->check( { config => $config } );


    is( $results->{react}->[0]->{subject},
        "GRID::Machine connecting to $config->{host}",
        "Checking that GRID::Machine connection established to $config->{host}"
    );

    is_deeply( $results->{react}->[1],
               { %{ $message }, count => 1 },
               "Checking that message 1 was received in 'results'"
           );
}

{
    my $results = $remote_queue->check( { config => $config } );

    is_deeply( $results->{react}->[0],
               { %{ $message }, count => 2 },
               "Checking that message 2 was received in 'results'"
           );
}

ok( ! $remote_queue->check( { config => $config } ),
    "Checking that no messages left in queue"
);
