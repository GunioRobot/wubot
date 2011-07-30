#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';

use Wubot::Logger;
use Wubot::LocalMessageStore;
use Wubot::Reactor::HTMLStrip;

no utf8;

ok( my $strip = Wubot::Reactor::HTMLStrip->new(),
    "Creating new console reactor object"
);

is( queue_dequeue_and_strip( 'test message' ),
    'test message',
    "Stripping HTML from subject with no HTML"
);

is( queue_dequeue_and_strip( '“foo”' ),
    '“foo”',
    "Stripping HTML from subject with no HTML"
);

is( queue_dequeue_and_strip( 'this is the &quot;test&quot; subject' ),
    'this is the "test" subject',
    "Stripping HTML from subject with HTML entity"
);

is( queue_dequeue_and_strip( 'this is wu&#8217;s subject' ),
    'this is wu’s subject',
    "Stripping HTML from subject with utf-8 HTML entity"
);

{
    my $utf_string = "\x{100}";
    utf8::encode( $utf_string );

    is( queue_dequeue_and_strip( "a \xc4\x80 b" ),
        "a $utf_string b",
        "Stripping HTML from subject with utf-8 encoded string"
    );

    is( queue_dequeue_and_strip( "a $utf_string b" ),
        "a $utf_string b",
        "Stripping HTML from subject with utf-8 decoded string"
    );

}



sub queue_dequeue_and_strip {
    my ( $subject ) = @_;

    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
    #print "Tempdir: $tempdir\n";

    #print "Creating messenger\n";
    my $messenger = Wubot::LocalMessageStore->new();

    #print "Storing message\n";
    my $message;
    $message->{subject} = $subject,
    $message->{key}     = 'test';
    $messenger->store( $message, $tempdir );

    #print "Retrieving from storage\n";
    my $got_message = $messenger->get( $tempdir );

    #print "Stripping\n";
    my $return = $strip->react( $message, { field => 'subject' }  );

    return $return->{subject_text};
}

