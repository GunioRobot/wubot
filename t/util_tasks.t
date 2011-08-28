#!/perl
use strict;
use warnings;

use Test::More tests => 49;

use File::Temp qw/ tempdir /;
use YAML;

BEGIN {
    $ENV{TZ} = "America/Los_Angeles";
}

use Wubot::Logger;
use Wubot::Util::Tasks;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );


ok( my $taskutil = Wubot::Util::Tasks->new( { dbfile => "$tempdir/tasks.ql" } ),
    "Creating new taskutil object"
);

{

    my $date_string = '2011-08-22 Mon 10:30';
    my $date_utime  = 1314034200;

    my $body = "  - [X] do this first
  - [ ] do this second";

    my $content = "* Tasks

** TODO [#A] 1h test meeting
   DEADLINE: <$date_string +1w>

$body

";

    my $task1_h = { deadline_utime      => $date_utime,
                    deadline_recurrence => '+1w',
                    deadline_text       => $date_string,
                    duration            => '1h',
                    file                => 'test',
                    priority            => '2',
                    status              => 'todo',
                    taskid              => 'test.test meeting',
                    title               => 'test meeting',
                    type                => 'task',
                    body                => $body,
                };

    my $content2 = "* Tasks

** TODO [#A] 1h test meeting
   SCHEDULED: <$date_string +1w>

$body

";

    my $task2_h = { scheduled_utime      => $date_utime,
                    scheduled_recurrence => '+1w',
                    scheduled_text       => $date_string,
                    duration             => '1h',
                    file                 => 'test',
                    priority             => '2',
                    status               => 'todo',
                    taskid               => 'test.test meeting',
                    title                => 'test meeting',
                    type                 => 'task',
                    body                 => $body,
                };


    my $content3 = "* Tasks

** TODO [#A] 1h different test meeting
   SCHEDULED: <$date_string +1w>

$body

";

    my $task3_h = { scheduled_utime      => $date_utime,
                    scheduled_recurrence => '+1w',
                    scheduled_text       => $date_string,
                    duration             => '1h',
                    file                 => 'test',
                    priority             => '2',
                    status               => 'todo',
                    taskid               => 'test.different test meeting',
                    title                => 'different test meeting',
                    type                 => 'task',
                    body                 => $body,
                };


    {
        ok( my @results = $taskutil->parse_emacs_org_page( "test.org", $content ),
            "Parsing emacs org page content"
        );

        is( scalar @results,
            1,
            "Checking that one task was found on page"
        );

        is_deeply( $results[0],
                   $task1_h,
                   "Checking that task was parsed properly"
               );
    }

    ok( $taskutil->sync_tasks( "test", $task1_h ),
        "Calling 'sync' method on tasks"
    );

    {
        ok( my @results = $taskutil->get_tasks(),
            "Getting a list of tasks from the db"
        );

        is( scalar @results,
            1,
            "Checking that only 1 task was found in the database"
        );

        for my $param ( keys %{ $task1_h } ) {
            next if $param eq "type";

            is( $results[0]->{$param},
                $task1_h->{$param},
                "Checking $param on retrieved task"
            );
        }
    }


    {
        ok( my @results = $taskutil->parse_emacs_org_page( "test.org", $content2 ),
            "Parsing emacs org page content"
        );

        is( scalar @results,
            1,
            "Checking that one task was found on page"
        );

        is_deeply( $results[0],
                   $task2_h,
                   "Checking that task was parsed properly"
               );
    }

    {
        ok( $taskutil->sync_tasks( "test", $task2_h ),
            "Calling 'sync' method on tasks"
        );

        ok( my @results = $taskutil->get_tasks(),
            "Getting a list of tasks from the db"
        );

        is( scalar @results,
            1,
            "Checking that only 1 task was found in the database"
        );

        for my $param ( keys %{ $task2_h } ) {
            next if $param eq "type";

            is( $results[0]->{$param},
                $task2_h->{$param},
                "Checking $param on retrieved task"
            );
        }
    }

    {
        ok( $taskutil->sync_tasks( "test", $task3_h ),
            "Calling 'sync' method on tasks"
        );

        ok( my @results = $taskutil->get_tasks(),
            "Getting a list of tasks from the db"
        );

        is( scalar @results,
            1,
            "Checking that only 1 task was found in the database"
        );

        for my $param ( keys %{ $task3_h } ) {
            next if $param eq "type";

            is( $results[0]->{$param},
                $task3_h->{$param},
                "Checking $param on retrieved task"
            );
        }
    }


}

