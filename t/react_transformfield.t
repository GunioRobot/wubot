#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';

use App::Wubot::Logger;
use App::Wubot::LocalMessageStore;
use App::Wubot::Reactor::TransformField;

ok( my $transformer = App::Wubot::Reactor::TransformField->new(),
    "Creating new TransformField reactor object"
);

is_deeply( $transformer->react( { a => 'abc def ghi' }, { source_field   => 'a',
                                                          target_field   => 'b',
                                                      } ),
           { a => 'abc def ghi' },
           "transforming field with no search/replace is a nop"
       );

is_deeply( $transformer->react( { a => 'abc def ghi' }, { source_field   => 'a',
                                                          regexp_search  => ' def ',
                                                          regexp_replace => '',
                                                          target_field   => 'b',
                                                      } ),
           { a => 'abc def ghi', b => 'abcghi' },
           "transforming field 'a' into field 'b' with regex_search"
       );

is_deeply( $transformer->react( { a => 'abc def ghi' }, { source_field   => 'a',
                                                          regexp_search  => ' def ',
                                                          regexp_replace => 'xyz',
                                                          target_field   => 'b',
                                                      } ),
           { a => 'abc def ghi', b => 'abcxyzghi' },
           "transforming field 'a' into field 'b' with regex_search and regexp_replace"
       );

is_deeply( $transformer->react( { a => 'abc def ghi' }, { source_field   => 'a',
                                                          regexp_search  => ' def ',
                                                          regexp_replace => 'xyz',
                                                      } ),
           { a => 'abcxyzghi' },
           "transforming field 'a' in-place"
       );

is_deeply( $transformer->react( { a => 'abc def ghi def' }, { source_field   => 'a',
                                                              regexp_search  => 'def',
                                                              regexp_replace => 'xyz',
                                                              target_field   => 'b',
                                                          } ),
           { a => 'abc def ghi def', b => 'abc xyz ghi xyz' },
           "transforming with multiple replacements"
       );

is_deeply( $transformer->react( { a => '0123' }, { source_field   => 'a',
                                                   regexp_search  => '^0+',
                                               } ),
           { a => '123' },
           "trimming leading zero"
       );

is_deeply( $transformer->react( { a => '5' }, { source_field    => 'a',
                                                regexp_search   => '^',
                                                regexp_replace  => '0',
                                            } ),
           { a => '05' },
           "add leading zero"
       );

is_deeply( $transformer->react( { a => '5' }, { source_field    => 'a',
                                                regexp_search   => '^(.)$',
                                                regexp_replace  => '0$1',
                                            } ),
           { a => '05' },
           "capture data and reference captured data in replace string"
       );

