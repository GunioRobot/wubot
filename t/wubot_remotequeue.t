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

my @reactions;

my $init = { key        => 'RemoteQueue-testcase',
             class      => 'Wubot::Plugin::RemoteQueue',
             cache_file => '/dev/null',
             reactor    => sub { push @reactions, $_[0] },
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

    for my $count ( 0 .. 19 ) {
        ok( $messenger->store( { %{ $message }, count => $count }, $tempdir ),
            "Storing message"
        );
    }
}

my $config  = { host => 'localhost',
                path => $tempdir,
                perl => '/usr/local/bin/perl',
            };

{
    ok( ! $remote_queue->check( { config => $config } ),
        "Calling check() method on remote queue"
    );

    is( $reactions[0]->{subject},
        "GRID::Machine connecting to $config->{host}",
        "Checking that GRID::Machine connection established to $config->{host}"
    );
    undef @reactions;

}

{
    ok( ! $remote_queue->check( { config => $config } ),
        "Calling check() method on remote queue"
    );

    for my $idx ( 0 .. 9 ) {

        is( $reactions[ $idx ]->{count},
            $idx,
            "Checking that GRID::Machine connection pulled first 10 messages from queue"
        );

    }
    undef @reactions;

}

{
    ok( ! $remote_queue->check( { config => $config } ),
        "Calling check() method on remote queue"
    );

    for my $idx ( 0 .. 9 ) {

        is( $reactions[ $idx ]->{count},
            $idx + 10,
            "Checking that GRID::Machine connection pulled second 10 messages from queue"
        );

    }
    undef @reactions;

}

{
    ok( ! $remote_queue->check( { config => $config } ),
        "Calling check() with no messages left in queue"
    );

    is_deeply( \@reactions,
               [],
               "Checking that no messages left in queue"
           );

}
