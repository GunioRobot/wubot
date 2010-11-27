#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';
use YAML;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO);
my $logger = get_logger( 'default' );

use Wubot::LocalMessageStore;


{
    my $directory = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $message = { foo        => 1,
                    checksum   => 1234,
                    key        => 'testcase',
                    lastupdate => time,
                };

    ok( my $messenger = Wubot::LocalMessageStore->new(),
        "Creating a new messenger"
    );

    ok( $messenger->store( { %{ $message } }, $directory ),
        "Storing message"
    );

    ok( my $got_message = $messenger->get( $directory ),
        "Retrieving only message in queue"
    );

    is_deeply( $got_message,
               $message,
               "Checking that retrieved message matches sent message"
           );

    is_deeply( [ $messenger->get( $directory ) ],
               [],
               "Checking that no messages left in queue"
           );

}


{
    my $directory = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $message = { foo        => 1,
                    checksum   => 1234,
                    key        => 'testcase',
                };

    my $timestamp = time - 10000;

    ok( my $messenger = Wubot::LocalMessageStore->new(),
        "Creating a new messenger"
    );

    for my $message_number ( 1 .. 9 ) {

        ok( $messenger->store( { %{ $message, },
                                 number => $message_number,
                                 lastupdate => $timestamp+$message_number*100,
                             }, $directory ),
            "Storing message number $message_number"
        );
    }

    for my $message_number ( 1 .. 9 ) {

        is_deeply( [ $messenger->get( $directory ) ],
                   [ { %{ $message },
                     number     => $message_number,
                     lastupdate => $timestamp+$message_number*100,
                 } ],
                   "Checking retrieved message order sorts properly with different dates"
               );
    }

    is_deeply( [ $messenger->get( $directory ) ],
               [],
               "Checking that no messages left in queue"
           );

}


{
    my $directory = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $message = { foo        => 1,
                    checksum   => 1234,
                    key        => 'testcase',
                };

    my $timestamp = time - 10000;

    my $messenger = Wubot::LocalMessageStore->new();

    for my $message_number ( 1 .. 19 ) {
        $messenger->store( { %{ $message, },
                             reactor_id => $message_number,
                             lastupdate => $timestamp,
                         }, $directory );
    }

    my @message_order;
    for my $message_number ( 1 .. 19 ) {
        push @message_order, $messenger->get( $directory )->{reactor_id};
    }

    is_deeply( [ @message_order ],
               [ 1 .. 19 ],
               "Checking sort order on message in queue where timestamp is identical"
           );
}



{
    my $directory = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $messenger = Wubot::LocalMessageStore->new();

    is_deeply( [ $messenger->get( $directory ) ],
               [ ],
               "Calling get() when 'new' sub-directory does not exist"
           );
}

