#!/perl
use strict;

use Test::More 'no_plan';
use YAML;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO);

use Wubot::Reactor;

my $config_src = <<"EOF";
---
rules:
  - name: key is TestCase-test1
    condition: key = TestCase-test1
    plugin: AddField
    config:
      field: test_field_test1
      value: test_value_test1
  - name: key matches ^TestCase2
    condition: key =~ ^TestCase2
    plugin: AddField
    config:
      field: test_field_test2
      value: test_value_test2
  - name: key matches ^TestCase
    condition: key =~ ^TestCase
    plugin: AddField
    config:
      field: test_field_test3
      value: test_value_test3
  - name: has field foo
    condition: contains foo
    plugin: AddField
    config:
      field: test_field_test4
      value: test_value_test4
  - name: foo is testpass2
    condition: foo = testpass2
    plugin: AddField
    config:
      field: test_field_test4
      value: test_value_test5

EOF

my $config = YAML::Load( $config_src );

my $reactor = Wubot::Reactor->new( config => $config );

ok( $reactor->react( { test => 'true' } ),
    "Calling react() with a minimal test message"
);

ok( $reactor->react( { test => 'true', key => 'TestCase-test1' } ),
    "Calling react() with test key matching key_is config"
);

is( $reactor->react( { test => 'true', key => 'TestCase-test1' } )->{test_field_test1},
    'test_value_test1',
    "checking test_successful message with test key matching key_is"
);

is( $reactor->react( { test => 'true', key => 'TestCase2-test2' } )->{test_field_test2},
    'test_value_test2',
    "checking test_successful message with test key matching key_matches"
);


is( $reactor->react( { test => 'true', key => 'TestCase1-test1' } )->{test_field_test3},
    'test_value_test3',
    "checking test message field with test key matching multiple rules"
);


is( $reactor->react( { test => 'true', key => 'TestCase1-test1' } )->{test_field_test3},
    'test_value_test3',
    "checking test message field with test key matching multiple rules"
);


is( $reactor->react( { foo => 'true' } )->{test_field_test4},
    'test_value_test4',
    "checking test message field with test key matching field_has rule"
);


is( $reactor->react( { foo => 'testpass2' } )->{test_field_test4},
    'test_value_test5',
    "checking pass 2 overwrote value set in pass 1"
);


