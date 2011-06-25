#!/perl
use strict;

use Test::More 'no_plan';
use YAML;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);

use Wubot::Reactor;

my $config_src = <<"EOF";
---
rules:
  - name: key is TestCase-test1
    condition: key equals TestCase-test1
    plugin: SetField
    config:
      field: test_field_test1
      value: test_value_test1
  - name: key matches ^TestCase2
    condition: key matches ^TestCase2
    plugin: SetField
    config:
      field: test_field_test2
      value: test_value_test2
  - name: key matches ^TestCase
    condition: key matches ^TestCase
    plugin: SetField
    config:
      field: test_field_test3
      value: test_value_test3
  - name: has field foo
    condition: contains foo
    plugin: SetField
    config:
      field: test_field_test4
      value: test_value_test4
  - name: foo is testpass2
    condition: foo equals testpass2
    plugin: SetField
    config:
      field: test_field_test4
      value: test_value_test5
  - name: array rule
    condition: contains test_array
    rules:
      - name: test_array_1
        plugin: SetField
        config:
          field: test_array_1
          value: test_value_1
      - name: test_array_1
        plugin: SetField
        config:
          field: test_array_2
          value: test_value_2
  - name: tree rule
    condition: contains test_tree
    rules:
      - name: test_tree_always
        plugin: SetField
        config:
          field: test_tree_1
          value: test_value_1
      - name: test_tree_foo
        condition: contains foo
        plugin: SetField
        config:
          field: test_tree_foo
          value: test_value_1
        rules:
          - name: test_tree_bar
            condition: contains bar
            plugin: SetField
            config:
              field: test_tree_bar
              value: test_value_1
  - name: key is TestCase-test6 with 'last_rule' set
    condition: key equals TestCase-test6
    plugin: SetField
    config:
      field: test_field_test6
      value: test_value_test6
    last_rule: 1
  - name: key is TestCase-test6, should not run due to 'last_rule'
    condition: key equals TestCase-test6
    plugin: SetField
    config:
      field: test_field_test6
      value: test_value_test7
  - name: key is TestCase-test8
    condition: key equals TestCase-test8
    last_rule: 1

EOF

my $config = YAML::Load( $config_src );

my $reactor = Wubot::Reactor->new( config => $config );

# react()
{
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
        "checking later rule overwrote value set in earlier rule"
    );

    is( $reactor->react( { test_array => 1 } )->{test_array_1},
        'test_value_1',
        "checking first rule in a rule array"
    );

    is( $reactor->react( { test_array => 1 } )->{test_array_2},
        'test_value_2',
        "checking second rule in a rule array"
    );

    is( $reactor->react( { test_tree => 1 } )->{test_tree_1},
        'test_value_1',
        "checking rule tree rule with no condition ran"
    );

    is( $reactor->react( { test_tree => 1 } )->{test_tree_foo},
        undef,
        "checking rule tree rule with non-matching condition did not ran"
    );

    is( $reactor->react( { test_tree => 1, foo => 1 } )->{test_tree_foo},
        'test_value_1',
        "checking rule tree rule with matching condition ran"
    );

    is( $reactor->react( { test_tree => 1, foo => 1 } )->{test_tree_bar},
        undef,
        "checking rule tree rule with non-matching condition three deep ran"
    );

    is( $reactor->react( { test_tree => 1, foo => 1, bar => 1 } )->{test_tree_bar},
        'test_value_1',
        "checking rule tree rule with matching condition three deep ran"
    );

    is( $reactor->react( { key => 'TestCase-test6' } )->{test_field_test6},
        'test_value_test6',
        "checking 'last_rule' prevents further rules from processing"
    );

    is( $reactor->react( { key => 'TestCase-test6' } )->{no_more_rules},
        1,
        "checking 'last_rule' set 'no_more_rules' field"
    );

    is( $reactor->react( { key => 'TestCase-test7' } )->{no_more_rules},
        undef,
        "Check that 'no_more_rules' field not set by default"
    );

    is( $reactor->react( { key => 'TestCase-test8' } )->{no_more_rules},
        1,
        "checking 'last_rule' set 'no_more_rules' field"
    );
}

# condition()
{
    ok( $reactor->condition( "foo matches test", { foo => 'test' } ),
        "Checking 'foo matches test' when foo = test"
    );

    ok( $reactor->condition( "foo matches test", { foo => 'test1' } ),
        "Checking 'foo matches test' when foo = test1"
    );

    ok( ! $reactor->condition( "foo matches test", { foo => 'asdf' } ),
        "Checking 'foo matches test' when foo = asdf"
    );

    ok( $reactor->condition( "foo equals test", { foo => 'test' } ),
        "Checking 'foo equals test' when foo = test"
    );

    ok( ! $reactor->condition( "foo equals test", { foo => 'test1' } ),
        "Checking 'foo equals test' when foo = test1"
    );

    ok( $reactor->condition( "contains foo", { foo => 'test1' } ),
        "Checking 'contains foo' when foo = test1"
    );

    ok( $reactor->condition( "contains foo", { foo => undef } ),
        "Checking 'contains foo' when foo = undef"
    );

    ok( ! $reactor->condition( "contains bar", { foo => 'test1' } ),
        "Checking 'contains bar' when it does not"
    );

    ok( $reactor->condition( "foo is true", { foo => 'test1' } ),
        "Checking 'foo is true' when foo = test1"
    );

    ok( ! $reactor->condition( "foo is true", { foo => undef } ),
        "Checking 'foo is true' when foo = undef"
    );

    ok( ! $reactor->condition( "foo is true", { foo => 0 } ),
        "Checking 'foo is true' when foo = 0"
    );

    ok( ! $reactor->condition( "foo is true", { foo => "" } ),
        "Checking 'foo is true' when foo = blank"
    );

    ok( $reactor->condition( "foo is true", { foo => "true" } ),
        "Checking 'foo is true' when foo = true"
    );

    ok( ! $reactor->condition( "foo is true", { foo => "false" } ),
        "Checking 'foo is true' when foo = false"
    );

    ok( ! $reactor->condition( "foo is false", { foo => 'test1' } ),
        "Checking 'foo is false' when foo = test1"
    );

    ok( $reactor->condition( "foo is false", { foo => undef } ),
        "Checking 'foo is false' when foo = undef"
    );

    ok( $reactor->condition( "foo is false", { foo => 0 } ),
        "Checking 'foo is false' when foo = 0"
    );

    ok( $reactor->condition( "foo is false", { foo => "" } ),
        "Checking 'foo is false' when foo = blank"
    );

    ok( $reactor->condition( "foo is false", { foo => "false" } ),
        "Checking 'foo is false' when foo = false"
    );

    ok( ! $reactor->condition( "foo is false", { foo => "true" } ),
        "Checking 'foo is false' when foo = true"
    );

    ok( $reactor->condition( "foo is true AND bar is true", { foo => "abc", bar => "def" } ),
        "Checking compound rule 'foo is true AND bar is true' when foo and bar are true"
    );

    ok( ! $reactor->condition( "foo is true AND bar is true", { foo => "abc" } ),
        "Checking compound rule 'foo is true AND bar is true' when bar is not set"
    );

    ok( $reactor->condition( "foo is true OR bar is true", { foo => "abc", bar => "def" } ),
        "Checking compound rule 'foo is true OR bar is true' when foo and bar are true"
    );

    ok( $reactor->condition( "foo is true OR bar is true", { foo => "abc" } ),
        "Checking compound rule 'foo is true OR bar is true' when bar is not set"
    );

    ok( ! $reactor->condition( "foo is true OR bar is true", { 'abc' => 'xyz' } ),
        "Checking compound rule 'foo is true OR bar is true' when both are not set"
    );

    ok( ! $reactor->condition( "NOT foo is true", { foo => 'test1' } ),
        "Checking 'NOT foo is true' when foo = test1"
    );

    ok( ! $reactor->condition( "NOT foo is true AND NOT bar is true", { foo => "abc", bar => "def" } ),
        "Checking compound rule 'NOT foo is true AND NOT bar is true' when foo and bar are true"
    );

    ok( $reactor->condition( "NOT foo is true AND NOT bar is true", { 'abc' => 'def' } ),
        "Checking compound rule 'NOT foo is true AND NOT bar is true' when foo and bar are false"
    );

    ok( ! $reactor->condition( "hostname equals navi AND NOT no_post is true", { hostname => 'xyz' } ),
        "Checking 'hostname equals navi AND NOT no_post is true no_post' when hostname is xyz"
    );

    ok( ! $reactor->condition( "hostname equals navi AND NOT no_post is true", { no_post => 1 } ),
        "Checking 'hostname equals navi AND NOT no_post is true no_post' when no_post set"
    );

    ok( ! $reactor->condition( "hostname equals navi AND NOT no_post is true", { hostname => 'xyz', no_post => 1 } ),
        "Checking 'hostname equals navi AND NOT no_post is true no_post' when hostname is xyz and no_post set"
    );

    ok( $reactor->condition( "hostname equals navi AND NOT no_post is true", { hostname => 'navi' } ),
        "Checking 'hostname equals navi AND NOT no_post is true no_post' when hostname is navi and no_post is unset"
    );

    ok( $reactor->condition( "hostname equals navi AND hostname equals navi OR hostname equals navi", { hostname => 'navi' } ),
        "Checking 'true AND true OR true' is true"
    );
    ok( $reactor->condition( "hostname equals navi AND hostname equals navi OR abc equals xyz", { hostname => 'navi' } ),
        "Checking 'true AND true OR false' is true"
    );
    ok( $reactor->condition( "hostname equals navi AND abc equals xyz OR hostname equals navi", { hostname => 'navi' } ),
        "Checking 'true AND false OR true' is true"
    );
    ok( ! $reactor->condition( "abc equals xyz AND hostname equals navi OR hostname equals navi", { hostname => 'navi' } ),
        "Checking 'false AND true OR true' is false"
    );
    ok( ! $reactor->condition( "abc equals xyz AND abc equals xyz OR hostname equals navi", { hostname => 'navi' } ),
        "Checking 'false AND false OR true' is false"
    );
    ok( ! $reactor->condition( "abc equals xyz AND hostname equals navi OR  abc equals xyz", { hostname => 'navi' } ),
        "Checking 'false AND true OR false' is false"
    );
    ok( ! $reactor->condition( "hostname equals navi AND abc equals xyz OR abc equals xyz", { hostname => 'navi' } ),
        "Checking 'true AND false OR false' is false"
    );
    ok( ! $reactor->condition( "abc equals xyz AND abc equals xyz OR abc equals xyz", { hostname => 'navi' } ),
        "Checking 'false AND false OR false' is false"
    );

}
