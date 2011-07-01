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

ok( my $state = Wubot::Reactor::State->new(),
    "Creating new State reactor object"
);

is_deeply( $state->react( { key => 'TestCase', a => 5 }, { field => 'a' } ),
           { key           => 'TestCase',
             a             => 5,
             subject       => 'TestCase: a changed: 0 => 5',
             state_change  => 5,
             state_init    => 1,
             state_changed => 1,
         },
           "Checking that state change detected and recorded on startup"
       );

is_deeply( $state->react( { key => 'TestCase', a => 5 }, { field => 'a' } ),
           { key           => 'TestCase',
             a             => 5,
         },
           "Checking that unchanged state not recorded"
       );

is_deeply( $state->react( { key => 'TestCase', a => 6 }, { field => 'a' } ),
           { key           => 'TestCase',
             a             => 6,
             subject       => 'TestCase: a changed: 5 => 6',
             state_change  => 1,
             state_changed => 1,
         },
           "Checking that state change detected and recorded"
       );

is_deeply( $state->react( { key => 'TestCase', a => 8 }, { field => 'a', increase => 1 } ),
           { key           => 'TestCase',
             a             => 8,
             subject       => 'TestCase: a increased: 6 => 8',
             state_change  => 2,
             state_changed => 1,
         },
           "Checking that state change increase detected and recorded"
       );

is_deeply( $state->react( { key => 'TestCase', a => 3 }, { field => 'a', increase => 1 } ),
           { key           => 'TestCase',
             a             => 3,
             state_change  => -5,
         },
           "Checking that state change increase not detected on decrease"
       );

is_deeply( $state->react( { key => 'TestCase', a => 8 }, { field => 'a', decrease => 1 } ),
           { key           => 'TestCase',
             a             => 8,
             state_change  => 5,
         },
           "Checking that state change increase detected and recorded"
       );

is_deeply( $state->react( { key => 'TestCase', a => 3 }, { field => 'a', decrease => 1 } ),
           { key           => 'TestCase',
             a             => 3,
             subject       => 'TestCase: a decreased: 8 => 3',
             state_change  => -5,
             state_changed => 1,
         },
           "Checking that state change increase not detected on decrease"
       );

