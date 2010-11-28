#!/perl
use strict;
use warnings;

use Test::More 'no_plan';

use Wubot::Reactor::Growl;

ok( my $growl = Wubot::Reactor::Growl->new(),
    "Creating new growl reactor object"
);

is( $growl->react( { subject => 'foo' } )->{growl}->{results},
    1,
    "Checking that notification sent if message contains a subject"
);

is( $growl->react( { foo => 'bar' } ),
    undef,
    "Checking that no notification sent if message does not contain a subject"
);

is( $growl->react( { subject => 'foo', quiet => 1 } ),
    undef,
    "Checking that growl notification skipped when 'quiet' flag set"
);

is( $growl->react( { subject => 'foo', quiet_growl => 1 } ),
    undef,
    "Checking that growl notification skipped when 'quiet_growl' flag set"
);

#_* priority

is( $growl->react( { subject => 'foo', priority => 10 } )->{growl}->{priority},
    10,
    "Checking that growl_priority set to message priority"
);

is( $growl->react( { subject => 'red', color => 'red' } )->{growl}->{priority},
    2,
    "Checking that growl_priority set to '2' if message color is red"
);

is( $growl->react( { subject => 'yellow', color => 'yellow' } )->{growl}->{priority},
    1,
    "Checking that growl_priority set to '1' if message color is yellow"
);

is( $growl->react( { subject => 'grey', color => 'grey' } )->{growl}->{priority},
    0,
    "Checking that growl_priority set to '0' if message color is grey"
);

is( $growl->react( { subject => 'green', color => 'green' } )->{growl}->{priority},
    -1,
    "Checking that growl_priority set to '-1' if message color is green"
);

is( $growl->react( { subject => 'blue', color => 'blue' } )->{growl}->{priority},
    -2,
    "Checking that growl_priority set to '-2' if message color is blue"
);

is( $growl->react( { subject => 'non-sticky' } )->{growl}->{sticky},
    0,
    "Checking that 'sticky' not enabled by default"
);

is( $growl->react( { subject => 'sticky', sticky => 1 } )->{growl}->{sticky},
    1,
    "Checking that 'sticky' enabed when message 'sticky' flag set"
);

{
    ok( my $results = $growl->react( { subject => 'sticky red for urgent', urgent => 1 } ),
        "sending urgent notification"
    );

    is( $results->{growl}->{sticky},
        1,
        "Checking that 'sticky' enabed when message 'urgent' flag set"
    );

    is( $results->{growl}->{color},
        'red',
        "Checking that 'color' set to 'red' when message 'urgent' flag set"
    );
}

is( $growl->react( { subject => 'image test' } )->{growl}->{image},
    "$ENV{HOME}/.icons/wubot.png",
    "Checking for default growl image",
);

is( $growl->react( { subject => '“foo”' } )->{growl}->{subject},
    '“foo”',
    "Checking growl with utf text"
);


# todo:
#  image
#  urgent
#  errmsg
#  service
