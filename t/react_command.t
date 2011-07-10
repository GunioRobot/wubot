#!/perl
use strict;
use warnings;

use Log::Log4perl qw(:easy);
use Test::More 'no_plan';
use YAML;

Log::Log4perl->easy_init($INFO);

use Wubot::Reactor::Command;

ok( my $command = Wubot::Reactor::Command->new(),
    "Creating new console reactor object"
);

my $pwd = `pwd`;
chomp $pwd;

is( $command->react( { }, { command => 'pwd' } )->{command_output},
    $pwd,
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

