#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::More 'no_plan';

use Wubot::Logger;
use Wubot::Reactor::WebFetch;

my $expected_content = "<title>Google</title>";

ok( my $fetch = Wubot::Reactor::WebFetch->new(),
    "Creating new WebFetch reactor object"
);

{
    ok( my $results = $fetch->react( { title   => 'test' },
                                     { url     => 'http://www.google.com',
                                       field   => 'body',
                                   } ),
        "Calling fetch for 'body' field from google"
    );

    like( $results->{body},
          qr/$expected_content/i,
          "Checking that body field contains google content"
      );
}

{
    ok( my $results = $fetch->react( { title => 'test',
                                       myurl => 'http://www.google.com',
                                   },
                                     { url_field => 'myurl',
                                       field     => 'body',
                                   } ),
        "Calling fetch for 'body' field from url on field myurl"
    );

    like( $results->{body},
          qr/$expected_content/i,
          "Checking that body field contains google content"
      );
}

