#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';

use App::Wubot::Logger;
use App::Wubot::LocalMessageStore;
use App::Wubot::Reactor::CaptureData;

ok( my $capture = App::Wubot::Reactor::CaptureData->new(),
    "Creating new CaptureData reactor object"
);

is_deeply( $capture->react( { a => 'abc def ghi' }, { source_field   => 'a',
                                                      target_field   => 'b',
                                                      regexp         => '(d.f)',
                                                  } ),
           { a => 'abc def ghi', b => 'def' },
           "capturing with a regexp"
       );

is_deeply( $capture->react( { a => 'abc def ghi' }, { source_field   => 'a',
                                                      regexp         => '(d.f)',
                                                  } ),
           { a => 'def' },
           "capturing with a regexp in-place, no target_field"
       );

is_deeply( $capture->react( { a => 'abc def ghi', re => '(d.f)' }, { source_field   => 'a',
                                                                     regexp_field   => 're',
                                                                 } ),
           { a => 'def', re => '(d.f)' },
           "capturing with a regexp field"
       );
