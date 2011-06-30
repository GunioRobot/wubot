#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::More 'no_plan';

use Wubot::LocalMessageStore;
use Wubot::Reactor::CaptureData;

Log::Log4perl->easy_init($INFO);
my $logger = get_logger( 'default' );

ok( my $capture = Wubot::Reactor::CaptureData->new(),
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
