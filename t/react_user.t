#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';

use Wubot::Logger;
use Wubot::Reactor::User;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

ok( my $user = Wubot::Reactor::User->new( { directory => $tempdir } ),
    "Creating new User reactor object"
);


{
    my $config = {};

    is_deeply( $user->react( {}, $config ),
               {},
               "Empty message results in no reaction field"
           );

    is_deeply( $user->react( { username => 'wu' }, $config ),
               { username      => 'wu',
                 username_orig => 'wu',
             },
               "Checking user reactor when only simple username is set"
           );

    is_deeply( $user->react( { username => 'dude@somehost.com' }, $config ),
               { username        => 'dude',
                 username_orig   => 'dude@somehost.com',
                 username_domain => 'somehost.com',
             },
               'Checking user reactor for email address dude@somehost.com'
           );

    is_deeply( $user->react( { username => 'El Duderino <dude@somehost.com>' }, $config ),
               { username        => 'dude',
                 username_orig   => 'El Duderino <dude@somehost.com>',
                 username_domain => 'somehost.com',
                 username_full   => 'El Duderino',
             },
               'Checking email style: El Duderino <dude@somehost.com>'
           );

    is_deeply( $user->react( { username => '"El Duderino" <dude@somehost.com>' }, $config ),
               { username        => 'dude',
                 username_orig   => '"El Duderino" <dude@somehost.com>',
                 username_domain => 'somehost.com',
                 username_full   => 'El Duderino',
             },
               'Checking email style: "El Duderino" <dude@somehost.com>'
           );

    is_deeply( $user->react( { username => '"El Duderino"<dude@somehost.com>' }, $config ),
               { username        => 'dude',
                 username_orig   => '"El Duderino"<dude@somehost.com>',
                 username_domain => 'somehost.com',
                 username_full   => 'El Duderino',
             },
               'Checking email style: "El Duderino"<dude@somehost.com>'
           );

    is_deeply( $user->react( { username => 'dude|idle' }, $config ),
               { username         => 'dude',
                 username_orig    => 'dude|idle',
                 username_comment => 'idle',
             },
               "Checking irc style: dude|idle"
           );
    is_deeply( $user->react( { username => 'dude{idle}' }, $config ),
               { username        => 'dude',
                 username_orig    => 'dude{idle}',
                 username_comment => 'idle',
             },
               "Checking irc style: dude{idle}"
           );
}

# _read_user_info
{
    #use File::Temp qw/ tempdir /;

    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $dude = { aliases => { 'lebowski' => {} }, color => 'red' };
    YAML::DumpFile( "$tempdir/dude.yaml",  $dude );

    my $walter = { abc => 'def' };
    YAML::DumpFile( "$tempdir/walter.yaml", $walter );

    my $donny = { abc => 'xyz', def => 'pdq' };
    YAML::DumpFile( "$tempdir/donny.yaml", $donny );

    $dude->{username} = 'dude';
    $walter->{username} = 'walter';
    $donny->{username} = 'donny';

    my $reactor = Wubot::Reactor::User->new( { directory => $tempdir } );

    my $results = $reactor->_read_user_info();

    is_deeply( $results->{dude},
               $dude,
               "checking user info for dude"
           );

    is_deeply( $results->{walter},
               $walter,
               "checking user info for walter"
           );

    is_deeply( $results->{donny},
               $donny,
               "checking user info for donny"
           );

    is_deeply( $results->{lebowski},
               $dude,
               "checking user info for dude's alias 'lebowski'"
           );

    is_deeply( $reactor->react( { username => 'dude' }, {} ),
               { username       => 'dude',
                 username_orig  => 'dude',
                 color          => 'red',
             },
               "Checking user reactor gets color from user db"
           );

    is_deeply( $reactor->react( { username => 'lebowski' }, {} ),
               { username       => 'dude',
                 username_orig  => 'lebowski',
                 color          => 'red',
             },
               "Checking user reactor gets color and username from user db"
           );

    is_deeply( $reactor->react( { username => 'lebowski', color => 'blue' }, {} ),
               { username       => 'dude',
                 username_orig  => 'lebowski',
                 color          => 'red',
                 color_orig     => 'blue',
             },
               "Checking that username overridden param gets saved to param_orig"
           );

    is_deeply( $reactor->react( { username => 'lebowski', color => 'red' }, {} ),
               { username       => 'dude',
                 username_orig  => 'lebowski',
                 color          => 'red',
             },
               "Checking that username overridden param not saved to param_orig if value is unchanged"
           );

    is_deeply( $reactor->react( { username => 'lebowski', color => 'blue', color_orig => 'green' }, {} ),
               { username       => 'dude',
                 username_orig  => 'lebowski',
                 color          => 'red',
                 color_orig     => 'green',
             },
               "Checking that username overridden param does not overwrite existing param_orig"
           );

}
