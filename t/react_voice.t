#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::More 'no_plan';

Log::Log4perl->easy_init($DEBUG);

use Wubot::Reactor::Voice;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

ok( my $voice = Wubot::Reactor::Voice->new( queue => $tempdir  ),
    "Creating new voice reactor object"
);

is( $voice->react( { subject => 'voice', key => 'test' } )->{react}->{voice},
    "test: voice",
    "Checking that notification sent if message contains a subject"
);

ok( $voice->say(),
    "Calling say() with message in queue"
);

is( $voice->react( { foo => 'bar' } )->{react}->{voice},
    undef,
    "Checking that no notification sent if message does not contain a subject"
);

ok( ! $voice->say(),
    "Calling say() with no messages in queue"
);


my $transform_config = { 'TaskNotify' => 'task notify',
                     };

my @cases = (
    { subject  => 'foo',
      expected => 'test: foo',
  },
    { subject  => 'TaskNotify',
      expected => 'test: task notify',
  },
);

for my $case ( @cases ) {

    is( $voice->react( { subject => $case->{subject}, key => 'test' },
                       { transform => $transform_config }
                   )->{react}->{voice},

        $case->{expected},
        "Checking voice transformation: $case->{subject}"
    );

}
