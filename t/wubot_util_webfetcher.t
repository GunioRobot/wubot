#!/perl
use strict;

use Test::More 'no_plan';

use App::Wubot::Logger;
use App::Wubot::Util::WebFetcher;

ok( my $fetcher = App::Wubot::Util::WebFetcher->new(),
    "Creating a new fetcher"
);

ok( my $google_content = $fetcher->fetch( 'http://www.google.com/', {} ),
    "Fetching content from google with no config"
);

like( $google_content,
      qr/google/,
      "Checking google content"
  );

ok( my $futurama_episodes = $fetcher->fetch( 'http://epguides.com/Futurama/' ),
    "Getting futurama episodes web page"
);

$futurama_episodes =~ m/(M..bius Dick)/;

is( $1,
    'Möbius Dick',
    "Checking for utf8 character in futurama episode name"
);

