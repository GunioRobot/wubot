#!/perl
use strict;
use warnings;

use Test::Differences;
use Test::More tests => 27;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use YAML;

use Wubot::Logger;
use Wubot::Reactor::Command;

my $tempdir  = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
$tempdir .= "/tmp";

my $queuedir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
$queuedir .= "/queue";

{
    ok( my $command = Wubot::Reactor::Command->new( { logdir => $tempdir } ),
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
    ok( my $command = Wubot::Reactor::Command->new( { logdir => $tempdir } ),
        "Creating new command reactor object"
    );

    eq_or_diff( $command->react( { abc => 'xyz' }, { command => 'false' } ),
               { command_output => '', command_signal => 0, command_status => 1, abc => 'xyz' },
               "Checking react() run with a command that fails"
           );
}

{
    my $id = 'forker';

    my $command = Wubot::Reactor::Command->new( { logdir => $tempdir } );

    my $results_h = $command->react( { foo => 'abc' }, { command => 'sleep 3 && echo finished', fork => $id } );

    is( $results_h->{foo},
        'abc',
        "Checking react() returned original message after forking"
    );

    is( $results_h->{command_output},
        undef,
        "Checking react() run with a forked command"
    );

    ok( $results_h->{command_pid},
        "Checking react() returned command_pid of forked process"
    );

    my $lockfile    = join( "/", $command->logdir, "$id.pid" );
    my $logfile     = join( "/", $command->logdir, "$id.log" );
    my $resultsfile = join( "/", $command->logdir, "$id.yaml" );

    sleep 1;

    ok( -r $lockfile,
        "Checking that lockfile was created: $lockfile"
    );

    sleep 4;

    ok( ! -r $lockfile,
        "Checking that lockfile was removed: $lockfile"
    );

    ok( -r $logfile,
        "Checking that logfile was created"
    );

    eq_or_diff( $command->monitor(),
               [ { command_output => 'finished', command_signal => 0, command_status => 0, foo => 'abc' } ],
               "Checking background command results"
           );

    ok( ! -r $logfile,
        "Checking that logfile was removed when monitor() returned results"
    );


}

{
    my $id = 'separate';

    my $command = Wubot::Reactor::Command->new( { logdir => $tempdir, queuedir => $queuedir } );

    my $results1_h = $command->react( { foo => 'abc' }, { command => 'sleep 1 && echo finished1', fork => "$id.1" } );
    my $results2_h = $command->react( { foo => 'def' }, { command => 'sleep 1 && echo finished2', fork => "$id.2" } );

    ok( $results1_h->{command_pid},
        "Checking react() returned command_pid of forked process"
    );

    ok( ! $results1_h->{command_queued},
        "Checking react() for first process was not queued"
    );

    ok( $results2_h->{command_pid},
        "Checking react() for second process was not forked"
    );

    ok( ! $results2_h->{command_queued},
        "Checking react() for second process was queued"
    );

    sleep 3;

    eq_or_diff( $command->monitor(),
               [
                   { command_output => 'finished1', command_signal => 0, command_status => 0, foo => 'abc' },
                   { command_output => 'finished2', command_signal => 0, command_status => 0, foo => 'def' },
               ],
               "Checking background command results"
           );
}

{
    my $id = 'multi';

    my $command = Wubot::Reactor::Command->new( { logdir => $tempdir } );

    my $results1_h = $command->react( { foo => 'abc' }, { command => 'sleep 1 && echo finished1', fork => $id } );
    my $results2_h = $command->react( { foo => 'def' }, { command => 'sleep 1 && echo finished2', fork => $id } );
    my $results3_h = $command->react( { foo => 'def' }, { command => 'sleep 1 && echo finished3', fork => $id } );
    my $results4_h = $command->react( { foo => 'def' }, { command => 'sleep 1 && echo finished4', fork => $id } );

    ok( $results1_h->{command_pid},
        "Checking react() returned command_pid of forked process"
    );

    ok( ! $results1_h->{command_queued},
        "Checking react() for first process was not queued"
    );

    ok( ! $results2_h->{command_pid},
        "Checking react() for second process was not forked"
    );

    ok( $results2_h->{command_queued},
        "Checking react() for second process was queued"
    );

    sleep 3;
    eq_or_diff( $command->monitor(),
               [
                   { command_output => 'finished1', command_signal => 0, command_status => 0, foo => 'abc' },
               ],
               "Checking first background command results received when monitor() called"
           );

    sleep 3;
    eq_or_diff( $command->monitor(),
               [
                   { command_output => 'finished2', command_signal => 0, command_status => 0, foo => 'def' },
               ],
               "Checking second background command results received when monitor() called"
           );

    sleep 3;
    eq_or_diff( $command->monitor(),
               [
                   { command_output => 'finished3', command_signal => 0, command_status => 0, foo => 'def' },
               ],
               "Checking third background command results received when monitor() called"
           );

    sleep 3;
    eq_or_diff( $command->monitor(),
               [
                   { command_output => 'finished4', command_signal => 0, command_status => 0, foo => 'def' },
               ],
               "Checking fourth background command results received when monitor() called"
           );
}



# {
#     my $id = 'multi';

#     my $command = Wubot::Reactor::Command->new( { logdir => $tempdir } );

#     $command->react( { foo => 'a' }, { command => 'echo 1 >> $log && sleep 1 && echo 2',  fork => $id } );
#     $command->react( { foo => 'b' }, { command => 'echo 3 && sleep 1 && echo 4',  fork => $id } );
#     $command->react( { foo => 'c' }, { command => 'echo 5 && sleep 1 && echo 6',  fork => $id } );
#     $command->react( { foo => 'd' }, { command => 'echo 7 && sleep 1 && echo 8',  fork => $id } );
#     $command->react( { foo => 'e' }, { command => 'echo 9 && sleep 1 && echo 10', fork => $id } );

#     sleep 5;

#     my $logfile    = join( "/", $command->logdir, "$id.log" );


# }


# TODO: duplicate command suppression
# TODO: test background command failure
# TODO: parent process exits and child keeps running and is picked up by next process
# TODO: start time, run time
