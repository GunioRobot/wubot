#!/perl
use strict;

use Test::More 'no_plan';
use YAML;

use Wubot::Logger;
use Wubot::Reactor;

my $reactor = Wubot::Reactor->new();

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

    ok( ! $reactor->condition( "foo matches test", { foo => 'TEST' } ),
        "Checking 'foo does not match test' when foo = TEST"
    );

    ok( $reactor->condition( "foo imatches test", { foo => 'test' } ),
        "Checking 'foo imatches test' when foo = test"
    );

    ok( $reactor->condition( "foo imatches test", { foo => 'TEST' } ),
        "Checking 'foo imatches test' when foo = TEST"
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

    ok( $reactor->condition( "foo matches ^Abc", { foo => "Abc-def" } ),
        "Checking 'foo matches ^Abc' when foo = Abc-def"
    );

    ok( $reactor->condition( "foo matches now is the time", { foo => "now is the time for all" } ),
        "Checking 'foo matches now is the time' when foo = now is the time for all"
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


    ok( $reactor->condition( "foo matches x AND foo matches a b c", { foo => 'x a b c y' } ),
        "Checking 'foo matches x AND foo matches a b c' when foo = x a b c y"
    );
}


# greater than or less than
{

    ok( $reactor->condition( "foo < 5", { foo => '1' } ),
        "Checking 'foo < 5' when foo = 1"
    );

    ok( ! $reactor->condition( "foo < 5", { foo => '6' } ),
        "Checking 'foo < 5' when foo = 6"
    );

    ok( ! $reactor->condition( "foo > 5", { foo => '1' } ),
        "Checking 'foo > 5' when foo = 1"
    );

    ok( $reactor->condition( "foo > 5", { foo => '6' } ),
        "Checking 'foo > 5' when foo = 6"
    );

    
    ok( $reactor->condition( "foo >= 5", { foo => '6' } ),
        "Checking 'foo >= 5' when foo = 6"
    );

    ok( $reactor->condition( "foo >= 5", { foo => '5' } ),
        "Checking 'foo >= 5' when foo = 5"
    );

    ok( ! $reactor->condition( "foo >= 5", { foo => '4' } ),
        "Checking 'foo > 4' when foo = 4"
    );


    ok( $reactor->condition( "foo <= 5", { foo => '4' } ),
        "Checking 'foo <= 5' when foo = 4"
    );

    ok( $reactor->condition( "foo <= 5", { foo => '5' } ),
        "Checking 'foo <= 5' when foo = 5"
    );

    ok( ! $reactor->condition( "foo <= 5", { foo => '6' } ),
        "Checking 'foo <= 4' when foo = 6"
    );


    ok( ! $reactor->condition( "foo > bar", { foo => '6', bar => '7' } ),
        "Checking 'foo > bar' when foo = 6, bar = 7"
    );

    ok( $reactor->condition( "foo > bar", { foo => '7', bar => '6' } ),
        "Checking 'foo > bar' when foo = 7, bar = 6"
    );

    ok( $reactor->condition( "foo < bar", { foo => '6', bar => '7' } ),
        "Checking 'foo < bar' when foo = 6, bar = 7"
    );

    ok( ! $reactor->condition( "foo < bar", { bar => '6' } ),
        "Checking 'foo < bar' when foo is undefined"
    );
    
    ok( ! $reactor->condition( "foo < bar", { foo => '6' } ),
        "Checking 'foo < bar' when bar is undefined"
    );
    
}
