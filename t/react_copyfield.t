#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';

use App::Wubot::Logger;
use App::Wubot::LocalMessageStore;
use App::Wubot::Reactor::CopyField;

ok( my $transformer = App::Wubot::Reactor::CopyField->new(),
    "Creating new CopyField reactor object"
);

is_deeply( $transformer->react( { a => 'abc' }, { source_field   => 'a',
                                                  target_field   => 'b',
                                              } ),
           { a => 'abc', b => 'abc' },
           "copying source_field a to target_field b"
       );

is_deeply( $transformer->react( { a => 'abc', fieldname => 'a' },
                                { source_field_name   => 'fieldname',
                                  target_field   => 'b',
                              } ),
           { a => 'abc', b => 'abc', fieldname => 'a' },
           "copying source_field_name a to target_field b"
       );

is_deeply( $transformer->react( { a => 'abc', fieldname => 'b' },
                                { source_field      => 'a',
                                  target_field_name => 'fieldname',
                              } ),
           { a => 'abc', b => 'abc', fieldname => 'b' },
           "copying source_field_name a to target_field_name b"
       );


is_deeply( $transformer->react( { a => 'abc', fieldname_x => 'a', fieldname_y => 'b' },
                                { source_field_name   => 'fieldname_x',
                                  target_field_name   => 'fieldname_y',
                              } ),
           { a => 'abc', b => 'abc', fieldname_x => 'a', fieldname_y => 'b' },
           "copying source_field_name a to target_field_name b"
       );

