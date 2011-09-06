#!/perl
use strict;

use Test::More tests => 21;

use YAML;

use App::Wubot::Logger;
use App::Wubot::Reactor;

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

my $reactor = App::Wubot::Reactor->new( config => $config );

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

    is( $reactor->react( { key => 'TestCase-test6' } )->{last_rule},
        1,
        "checking 'last_rule' set 'last_rule' field"
    );

    is( $reactor->react( { key => 'TestCase-test7' } )->{last_rule},
        undef,
        "Check that 'last_rule' field not set by default"
    );

    is( $reactor->react( { key => 'TestCase-test8' } )->{last_rule},
        1,
        "checking 'last_rule' set 'last_rule' field"
    );
}

is_deeply( [ $reactor->find_plugins( $config->{rules} ) ],
           [ 'SetField' ],
           "Checking that SetField plugin was found"
       );

my $test_config =<<EOF;

---
rules:
  - name: abc rule
    plugin: ABC
    rules:
      - name: def rule
        plugin: DEF
        rules:
          - name: ghi rule
            plugin: GHI


EOF


is_deeply( [ $reactor->find_plugins( YAML::Load( $test_config )->{rules} ) ],
           [ qw( ABC DEF GHI ) ],
           "Checking that plugins were found in rule tree"
       );

