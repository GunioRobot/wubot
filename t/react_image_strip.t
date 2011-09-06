#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';

use App::Wubot::Logger;
use App::Wubot::Reactor::ImageStrip;

ok( my $strip = App::Wubot::Reactor::ImageStrip->new(),
    "Creating new console reactor object"
);

is( $strip->react( { body => 'some test body' }, { field => 'body' }  )->{body},
    'some test body',
    "Calling image remover on body with no image"
);

is( $strip->react( { body => 'some <img src="http://x.com/test.png"></img> test body' }, { field => 'body' }  )->{body},
    'some  test body',
    "Calling image remover on body with no image"
);

is( $strip->react( { body => 'some <img src="http://x.com/test.png" border="0" ismap="true"></img> test body' }, { field => 'body' }  )->{body},
    'some  test body',
    "Calling image remover on body with no image"
);

