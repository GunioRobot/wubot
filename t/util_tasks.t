#!/perl

use Test::More 'no_plan';

use YAML;

use Wubot::Logger;
use Wubot::Util::Tasks;

ok( my $taskutil = Wubot::Util::Tasks->new(),
    "Creating new taskutil object"
);

{
    my $body = "  - [X] do this first
  - [ ] do this second";

    my $content = "* Tasks

** TODO [#A] 1h test meeting
   DEADLINE: <2011-08-22 Mon 10:30 +1w>

$body

";

    my ( $results_h ) = $taskutil->parse_emacs_org_page( "test.org", $content );

    is_deeply( $results_h,
               { deadline            => 1314034200,
                 deadline_recurrence => '+1w',
                 deadline_text       => '2011-08-22 Mon 10:30',
                 duration            => '1h',
                 file                => 'test',
                 priority            => '2',
                 status              => 'todo',
                 taskid              => 'test.test meeting',
                 title               => 'test meeting',
                 type                => 'task',
                 body                => $body,
               },
               "Checking that task was parsed properly"
           );


}

