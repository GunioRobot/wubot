#!/perl
use strict;
use warnings;

use Test::More 'no_plan';

use Wubot::Reactor::Console;

ok( my $console = Wubot::Reactor::Console->new(),
    "Creating new console reactor object"
);

is( $console->react( { foo => 'bar' } )->{console},
    undef,
    "Checking that no message sent if no subject"
);

is( $console->react( { subject => 'quiet', quiet => 1, } )->{console},
    undef,
    "Checking that no message sent if quiet flag set"
);

is( $console->react( { subject => 'console quiet', quiet_console => 1 } )->{console},
    undef,
    "Checking that no message sent if quiet_console flag set"
);

like( $console->react( { subject => 'foo', key => 'TestCase-test1' } )->{console}->{text},
      qr/\[TestCase-test1\]\sfoo$/,
      "Checking subject for console notification ends in original text"
  );

like( $console->react( { subject => 'foo', title => 'bar',  key => 'TestCase-test1' } )->{console}->{text},
      qr/\[TestCase-test1\]\sbar \=\> foo$/,
      "Checking subject for console notification ends in original text"
  );

is( $console->react( { subject => 'orange message', color => 'yellow', urgent => 1, } )->{console}->{color},
    'bold yellow',
    "Checking that urgent flag triggers bold color"
);

is( $console->react( { subject => 'orange message', color => 'orange' } )->{console}->{color},
    'yellow',
    "Checking that 'orange' color displayed as 'yellow'"
);

is( $console->react( { subject => 'black message', color => 'black' } )->{console}->{color},
    'bold black',
    "Checking that 'bold black' color displayed properly"
);

