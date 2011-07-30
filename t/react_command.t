#!/perl
use strict;
use warnings;

use Test::Differences;
use Test::More tests => 21;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use YAML;

use Wubot::Logger;
use Wubot::Reactor::Command;

my $tempdir  = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
$tempdir .= "/tmp";

my $queuedir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
$queuedir .= "/queue";

my $queuedb = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
$queuedb .= "/commands.sql";

{
    ok( my $command = Wubot::Reactor::Command->new( { logdir => $tempdir, queuedb => $queuedb } ),
        "Creating new command reactor object"
    );

    my $pwd = `pwd`;
    chomp $pwd;

    eq_or_diff( $command->react( { abc => 'xyz' }, { command => 'pwd' } ),
               { command_output => $pwd, command_signal => 0, command_status => 0, abc => 'xyz' },
               "Checking react() run with a configured command"
           );

    is( $command->react( { test => 'pwd' }, { command_field => 'test' } )->{command_output},
        $pwd,
        "Checking react() run with a command from a field"
    );

    is( $command->react( { test => 'pwd' },
                         { command_field => 'test', output_field => 'test_output' }
                     )->{test_output},
        $pwd,
        "Checking react() with specified output field"
    );
}

{
    ok( my $command = Wubot::Reactor::Command->new( { logdir => $tempdir, queuedb => $queuedb } ),
        "Creating new command reactor object"
    );

    eq_or_diff( $command->react( { abc => 'xyz' }, { command => 'false' } ),
               { command_output => '', command_signal => 0, command_status => 1, abc => 'xyz' },
               "Checking react() run with a command that fails"
           );
}

{
    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $id = 'forker';

    my $command = Wubot::Reactor::Command->new( { logdir => $tempdir, queuedb => $queuedb } );

    my $queue_results_h = $command->react( { foo => 'abc' }, { command => 'sleep 4 && echo finished', fork => $id } );

    is( $queue_results_h->{foo},
        'abc',
        "Checking react() returned original message after forking"
    );

    is( $queue_results_h->{command_queued},
        1,
        "Checking that command was queued"
    );

    ok( ! $command->monitor(),
        "Calling monitor method to start task, no message sent"
    );

    sleep 3;

    ok( ! $command->monitor(),
        "Calling monitor method while task is still running, no message sent"
    );

    my $lockfile    = join( "/", $command->logdir, "$id.pid" );
    my $logfile     = join( "/", $command->logdir, "$id.log" );
    my $resultsfile = join( "/", $command->logdir, "$id.yaml" );

    ok( -r $lockfile,
        "Checking that pidfile was created"
    );

    ok( -r $logfile,
        "Checking that log file was created"
    );

    sleep 3;

    ok( ! -r $lockfile,
        "Checking that pidfile was removed when process exited"
    );

    # ok( -r $resultsfile,
    #     "Checking that results file was created"
    # );

    my $results_a = $command->monitor();

    is( scalar @{ $results_a },
        1,
        "Calling monitor method got 1 result"
    );

    my ( $results_h ) = @{ $results_a };

    eq_or_diff_data( \$results_h,
                     \{ command_output => 'finished',
                        command_signal => 0,
                        command_queue  => 'forker',
                        command_status => 0,
                        foo            => 'abc',
                        subject        => "Command succeeded: $id",
                    },
                     "Checking background command results"
                 );

    ok( ! -r $logfile,
        "Checking that logfile was removed"
    );

    ok( ! -r $resultsfile,
        "Checking that results file was removed"
    );
}

{
    my $id = 'separate';

    my $command = Wubot::Reactor::Command->new( { logdir => $tempdir, queuedir => $queuedir, queuedb => $queuedb } );

    my $results1_h = $command->react( { foo => 'abc' }, { command => 'sleep 1 && echo finished1', fork => "$id.1" } );
    my $results2_h = $command->react( { foo => 'def' }, { command => 'sleep 1 && echo finished2', fork => "$id.2" } );

    ok( $results1_h->{command_queued},
        "Checking react() for first process was not queued"
    );

    ok( $results2_h->{command_queued},
        "Checking react() for second process was queued"
    );

    ok( ! $command->monitor(),
        "calling monitor() method to start first command in queue"
    );

    sleep 3;

    eq_or_diff( \$command->monitor(),
                \[
                   { command_output => 'finished1',
                     command_queue => 'separate.1',
                     command_signal => 0,
                     command_status => 0,
                     foo            => 'abc',
                     subject        => "Command succeeded: $id.1",
                 },
                   { command_output => 'finished2',
                     command_queue => 'separate.2',
                     command_signal => 0,
                     command_status => 0,
                     foo            => 'def',
                     subject        => "Command succeeded: $id.2",
                 },
               ],
               "Checking background command results"
           );
}

# {
#     my $id = 'multi';

#     my $tempdir  = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
#     $tempdir .= "/tmp";

#     my $queuedir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
#     $queuedir .= "/queue";

#     my $queuedb = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
#     $queuedb .= "/commands.sql";

#     my $command = Wubot::Reactor::Command->new( { logdir => $tempdir, queuedir => $queuedir, queuedb => $queuedb } );

#     my $results1_h = $command->react( { foo => 'abc' }, { command => 'sleep 1 && echo finished1', fork => $id } );
#     my $results2_h = $command->react( { foo => 'def' }, { command => 'sleep 1 && echo finished2', fork => $id } );
#     my $results3_h = $command->react( { foo => 'def' }, { command => 'sleep 1 && echo finished3', fork => $id } );
#     my $results4_h = $command->react( { foo => 'def' }, { command => 'sleep 1 && echo finished4', fork => $id } );

#     ok( $results1_h->{command_pid},
#         "Checking react() returned command_pid of forked process"
#     );

#     ok( ! $results1_h->{command_queued},
#         "Checking react() for first process was not queued"
#     );

#     ok( ! $results2_h->{command_pid},
#         "Checking react() for second process was not forked"
#     );

#     ok( $results2_h->{command_queued},
#         "Checking react() for second process was queued"
#     );

#     sleep 3;
#     eq_or_diff( \$command->monitor(),
#                \[
#                    { command_output => 'finished1',
#                      command_signal => 0,
#                      command_status => 0,
#                      foo            => 'abc',
#                      subject        => "Command succeeded: $id",
#                  },
#                ],
#                "Checking first background command results received when monitor() called"
#            );

#     sleep 3;
#     eq_or_diff( \$command->monitor(),
#                \[
#                    { command_output => 'finished2',
#                      command_signal => 0,
#                      command_status => 0,
#                      foo            => 'def',
#                      subject        => "Command succeeded: $id",
#                  },
#                ],
#                "Checking second background command results received when monitor() called"
#            );

#     sleep 3;
#     eq_or_diff( \$command->monitor(),
#                \[
#                    { command_output => 'finished3',
#                      command_signal => 0,
#                      command_status => 0,
#                      foo            => 'def',
#                      subject        => "Command succeeded: $id",
#                  },
#                ],
#                "Checking third background command results received when monitor() called"
#            );

#     sleep 3;
#     eq_or_diff( \$command->monitor(),
#                \[
#                    { command_output => 'finished4',
#                      command_signal => 0,
#                      command_status => 0,
#                      foo            => 'def',
#                      subject        => "Command succeeded: $id",
#                  },
#                ],
#                "Checking fourth background command results received when monitor() called"
#            );

#     sleep 3;
#     eq_or_diff( $command->monitor(),
#                [],
#                "Checking that no processes remain"
#            );
# }


# # TODO: duplicate command suppression
# # TODO: test background command failure
# # TODO: parent process exits and child keeps running and is picked up by next process
# # TODO: start time, run time
