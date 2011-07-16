#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::More 'no_plan';

use Wubot::Logger;
use Wubot::Reactor::Icon;

ok( my $icon = Wubot::Reactor::Icon->new(),
    "Creating new Icon reactor object"
);

my $dir    = 't/icons';
my $config = { image_dir => $dir };

is_deeply( $icon->react( {}, $config ),
           { icon  => "$dir/wubot.png",
         },
           "Default icon is wubot.png"
       );

is_deeply( $icon->react( { image => 'test.png' }, $config ),
           { image => 'test.png',
             icon  => "$dir/test.png",
         },
           "Checking icon detector when 'image' is set in the field"
       );

is_deeply( $icon->react( { key => 'Test-foo' }, $config ),
           { key   => 'Test-foo',
             icon  => "$dir/test.png",
         },
           "Checking icon detector when image exists for plugin"
       );

is_deeply( $icon->react( { key => 'Foo-test' }, $config ),
           { key   => 'Foo-test',
             icon  => "$dir/test.png",
         },
           "Checking icon detector when image exists for instance id"
       );

is_deeply( $icon->react( { key => 'Foo-bar' }, $config ),
           { key   => 'Foo-bar',
             icon  => "$dir/foo-bar.png",
         },
           "Checking icon detector when image exists for plugin instance"
       );

is_deeply( $icon->react( { key => 'Foo-bar' }, $config ),
           { key   => 'Foo-bar',
             icon  => "$dir/foo-bar.png",
         },
           "Checking icon detector when image exists for plugin instance"
       );

is_deeply( $icon->react( { username => 'wu' }, $config ),
           { username  => 'wu',
             icon      => "$dir/wu.png",
         },
           "Checking icon detector when image exists for username"
       );

is_deeply( $icon->react( { username => 'wu@somehost.com' }, $config ),
           { username  => 'wu@somehost.com',
             icon      => "$dir/wu.png",
         },
           'Checking icon detector for email style: username@address'
       );

is_deeply( $icon->react( { username => 'fullname <wu@somehost.com>' }, $config ),
           { username  => 'fullname <wu@somehost.com>',
             icon      => "$dir/wu.png",
         },
           'Checking icon detector for email style: fullname <username@address>'
       );

is_deeply( $icon->react( { username => 'wu|idle' }, $config ),
           { username  => 'wu|idle',
             icon      => "$dir/wu.png",
         },
           "Checking icon detector for irc-style username|comment"
       );

