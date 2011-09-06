#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';

use App::Wubot::Logger;
use App::Wubot::Reactor::Icon;

ok( my $icon = App::Wubot::Reactor::Icon->new(),
    "Creating new Icon reactor object"
);

my $dir    = 't/icons';

{
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

}

{
    my $config = { image_dir => $dir,
                   custom    => { key      => { 'abc-xyz' => 'wu.png' },
                                  username => { 'dude'    => 'wu.png' },
                              },
               };

    is_deeply( $icon->react( { key => 'abc-xyz' }, $config ),
               { key   => 'abc-xyz',
                 icon  => "$dir/wu.png",
             },
               "Checking icon detector with custom image for key"
           );

    is_deeply( $icon->react( { username => 'dude' }, $config ),
               { username => 'dude',
                 icon     => "$dir/wu.png",
             },
               "Checking icon detector with custom username for wu"
           );
}
