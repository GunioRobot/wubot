#!/perl
use strict;

use Test::More 'no_plan';
use YAML;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO);

use Wubot::Plugin::MboxReader;

# note: install this for faster parsing!
#use Mail::Mbox::MessageParser;

my $test_file = "/Users/wu/tmp/wu";
my $key = "MboxReader-testcase";

ok( my $reader = Wubot::Plugin::MboxReader->new( key => $key ),
    "Creating a new reader object"
);

ok( $reader->check( { path => $test_file }, {} ),
    "Running the check() method and passing in the config"
);

{
    ok( my ( $results, $cache ) = $reader->check( { path => $test_file }, {} ),
        "Getting results and cache",
    );
}

{
    ok( my ( $results, $cache ) = $reader->check( { path => $test_file },
                                                  {
                                                      seen => { '<012801cb2f2e$d62cea60$8286bf20$@com>' => 1 } },
                                              ),
        "Getting results and cache",
    );
}

{
    ok( my ( $results, $cache ) = $reader->check( { path => $test_file },
                                                  {
                                                      seen => { 'abcdefg' => 1 } },
                                              ),
        "Getting results and cache",
    );

    #print YAML::Dump { results => $results };
    #print YAML::Dump { cache   => $cache   };

    ok( my ( $results2, $cache2 ) = $reader->check( { path => $test_file },
                                                    $cache,
                                                ),
        "Getting results and cache",
    );

    #print YAML::Dump { results => $results2 };

}




