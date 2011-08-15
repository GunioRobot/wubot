#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';

use Wubot::Logger;
use Wubot::Reactor::User;

ok( my $user = Wubot::Reactor::User->new(),
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
