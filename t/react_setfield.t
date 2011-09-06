#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';

use App::Wubot::Logger;
use App::Wubot::Reactor::SetField;

ok( my $setter = App::Wubot::Reactor::SetField->new(),
    "Creating new SetField reactor object"
);

is_deeply( $setter->react( { a => 'abc' }, { field => 'b',
                                             value => 'xyz',
                                         } ),
           { a => 'abc', b => 'xyz' },
           "setting field 'b' to value 'xyz'"
       );

is_deeply( $setter->react( { a => 'abc' }, { field => 'a',
                                             value => 'xyz',
                                         } ),
           { a => 'xyz' },
           "overriding field 'a'"
       );

is_deeply( $setter->react( { a => 'abc' }, { field => 'a',
                                             value => 'xyz',
                                             no_override => 1,
                                         } ),
           { a => 'abc' },
           "no_override on field 'a'"
       );

is_deeply( $setter->react( { a => 'abc' }, { set => { x => 'y', foo => 'bar' } } ),
           { a => 'abc', x => 'y', foo => 'bar' },
           "set x =y and foo = bar"
       );

is_deeply( $setter->react( { a => 'abc' }, { no_override => 1, set => { a => 'xyz', foo => 'bar' } } ),
           { a => 'abc', foo => 'bar' },
           "set with no_override"
       );
