#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::More 'no_plan';

use Wubot::LocalMessageStore;
use Wubot::Reactor::State;

Log::Log4perl->easy_init($INFO);
my $logger = get_logger( 'default' );

{
    ok( my $state = Wubot::Reactor::State->new(),
        "Creating new State reactor object"
    );

    is_deeply( $state->react( { key => 'TestCase', a => 5 }, { field => 'a' } ),
               { key           => 'TestCase',
                 a             => 5,
                 state_init    => 1,
             },
               "Checking that no state change detected on startup, and state_init flag set"
           );
}

my $cases = [
    { desc   => "checking with no state change, 2 times",
      config => { field => 'a', change => 1 },
      cases  => [ { key => 'TestCase', a => 5 }, { key => 'TestCase', a => 5 } ],
      expect => { key           => 'TestCase',
                  a             => 5,
              },
  },
    { desc   => "checking with no state change, 3 times",
      config => { field => 'a', change => 1 },
      cases  => [ { key => 'TestCase', a => 5 }, { key => 'TestCase', a => 5 }, { key => 'TestCase', a => 5 } ],
      expect => { key           => 'TestCase',
                  a             => 5,
              },
  },
    { desc   => "checking state for change on decrease",
      config => { field => 'a', change => 1 },
      cases  => [ { key => 'TestCase', a => 8 }, { key => 'TestCase', a => 3 } ],
      expect => { key           => 'TestCase',
                  a             => 3,
                  subject       => 'TestCase: a changed: 8 => 3',
                  state_change  => -5,
                  state_changed => 1,
              },
  },
    { desc   => "checking state for change on increase",
      config => { field => 'a', change => 1 },
      cases  => [ { key => 'TestCase', a => 3 }, { key => 'TestCase', a => 8 } ],
      expect => { key           => 'TestCase',
                  a             => 8,
                  subject       => 'TestCase: a changed: 3 => 8',
                  state_change  => 5,
                  state_changed => 1,
              },
  },
    { desc   => "checking insignificant state change, within threshold 5",
      config => { field => 'a', change => 5 },
      cases  => [ { key => 'TestCase', a => 5 }, { key => 'TestCase', a => 3 } ],
      expect => { key           => 'TestCase',
                  a             => 3,
                  state_change  => -2,
              },
  },
    { desc   => "checking insignificant state change, within threshold 5",
      config => { field => 'a', change => 5 },
      cases  => [ { key => 'TestCase', a => 5 }, { key => 'TestCase', a => 7 } ],
      expect => { key           => 'TestCase',
                  a             => 7,
                  state_change  => 2,
              },
  },
    { desc   => "checking state for decrease",
      config => { field => 'a', decrease => 1 },
      cases  => [ { key => 'TestCase', a => 8 }, { key => 'TestCase', a => 3 } ],
      expect => { key           => 'TestCase',
                  a             => 3,
                  subject       => 'TestCase: a decreased: 8 => 3',
                  state_change  => -5,
                  state_changed => 1,
              },
  },
    { desc   => "checking state for decrease when value increased",
      config => { field => 'a', decrease => 1 },
      cases  => [ { key => 'TestCase', a => 3 }, { key => 'TestCase', a => 8 } ],
      expect => { key           => 'TestCase',
                  a             => 8,
                  state_change  => 5,
              },
  },

    { desc   => "checking state for increase",
      config => { field => 'a', increase => 1 },
      cases  => [ { key => 'TestCase', a => 3 }, { key => 'TestCase', a => 8 } ],
      expect => { key           => 'TestCase',
                  a             => 8,
                  subject       => 'TestCase: a increased: 3 => 8',
                  state_change  => 5,
                  state_changed => 1,
              },
  },
    { desc   => "checking state for increase when value decreased",
      config => { field => 'a', increase => 1 },
      cases  => [ { key => 'TestCase', a => 8 }, { key => 'TestCase', a => 3 } ],
      expect => { key           => 'TestCase',
                  a             => 3,
                  state_change  => -5,
              },
  },

    { desc   => "increase threshold set to 10, but only increased by 2",
      config => { field => 'a', increase => 10 },
      cases  => [ { key => 'TestCase', a => 3 }, { key => 'TestCase', a => 5 } ],
      expect => { key           => 'TestCase',
                  a             => 5,
                  state_change  => 2,
              },
  },
    { desc   => "decrease threshold set to 10, but only decreased by 2",
      config => { field => 'a', decrease => 10 },
      cases  => [ { key => 'TestCase', a => 5 }, { key => 'TestCase', a => 3 } ],
      expect => { key           => 'TestCase',
                  a             => 3,
                  state_change  => -2,
              },
  },
];


for my $testcase ( @{ $cases } ) {

    #print YAML::Dump { testcase => $testcase };

    my $state = Wubot::Reactor::State->new();

    for my $idx ( 0 .. $#{ $testcase->{cases} } - 1 ) {
        $state->react( $testcase->{cases}->[$idx], $testcase->{config} );
        #print YAML::Dump { cases => $testcase->{cases} };
    }

    my $got = $state->react( $testcase->{cases}->[-1], $testcase->{config} );

    if ( $got->{subject} ) {
        $got->{subject} =~ s|\s\([\d\w]+\)$||;
    }

    is_deeply( $got,
               $testcase->{expect},
               $testcase->{desc}
           );

}

{
    my $state = Wubot::Reactor::State->new();

    is_deeply( [ $state->monitor() ],
               [ ],
               "Checking that monitor() returns no errors with no data in cache"
           );

    $state->cache->{testkey}->{testfield}->{lastupdate} = time - 50;

    is_deeply( [ $state->monitor() ],
               [ ],
               "Checking that monitor() returns no errors with cache data updated recently"
           );

    $state->cache->{testkey}->{testfield}->{lastupdate} = time - 2*24*60*60;

    is_deeply( [ $state->monitor() ],
               [ { subject => "Warning: cache data for testkey:testfield not updated in 2d",
                   key     => 'wubot-reactor'
               } ],
               "Checking that monitor() returns warning with lastupdate time > 5 minues"
           );

}
