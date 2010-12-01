#!/perl
use strict;
use warnings;

use Test::More 'no_plan';

use Wubot::Reactor::HTMLStrip;

ok( my $strip = Wubot::Reactor::HTMLStrip->new(),
    "Creating new console reactor object"
);

is( $strip->react( { subject => 'test message' }, { field => 'subject' } )->{subject_text},
    'test message',
    "Stripping HTML from subject with no HTML"
);

is( $strip->react( { subject => '“foo”' }, { field => 'subject' } )->{subject_text},
    '“foo”',
    "Stripping HTML from subject with no HTML"
);

is( $strip->react( { subject => 'this is the &quot;test&quot; subject' }, { field => 'subject' } )->{subject_text},
    'this is the "test" subject',
    "Stripping HTML from subject with HTML entity"
);

is( $strip->react( { subject => 'this is wu&#8217;s subject' }, { field => 'subject' } )->{subject_text},
    'this is wu’s subject',
    "Stripping HTML from subject with utf-8 HTML entity"
);
