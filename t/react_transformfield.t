#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::More 'no_plan';

use Wubot::LocalMessageStore;
use Wubot::Reactor::TransformField;

Log::Log4perl->easy_init($INFO);
my $logger = get_logger( 'default' );

ok( my $transformer = Wubot::Reactor::TransformField->new(),
    "Creating new TransformField reactor object"
);

is_deeply( $transformer->react( { a => 'abc def ghi' }, { source_field   => 'a',
                                                          regexp_search  => '',
                                                          regexp_replace => '',
                                                          target_field   => 'b',
                                                      } ),
           { a => 'abc def ghi', b => 'abc def ghi' },
           "transforming field 'a' into field 'b' with no change"
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

