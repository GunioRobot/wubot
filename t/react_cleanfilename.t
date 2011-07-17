#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::More 'no_plan';

use Wubot::Logger;

use Wubot::LocalMessageStore;
use Wubot::Reactor::CleanFilename;

ok( my $transformer = Wubot::Reactor::CleanFilename->new(),
    "Creating new CleanFilename reactor object"
);

is_deeply( $transformer->react( { file => 'abc def' },
                                { filename_field   => 'file' }
                            ),
           { file => 'abc_def' },
           "cleaning filename with a space"
       );

is_deeply( $transformer->react( { file => 'abc  def ghi' },
                                { filename_field   => 'file' }
                            ),
           { file => 'abc_def_ghi' },
           "cleaning filename with multiple spaces"
       );

is_deeply( $transformer->react( { file => 'abc;!@#$%^&*()+=def.txt' },
                                { filename_field   => 'file' }
                            ),
           { file => 'abc_def.txt' },
           "cleaning filename with special characters"
       );

is_deeply( $transformer->react( { file => 'abc_____def' },
                                { filename_field   => 'file' }
                            ),
           { file => 'abc_def' },
           "cleaning filename with multiple consecutive underscores"
       );
