#!/perl
use strict;
use warnings;

no utf8;

use Test::More;

for my $lib ( 'App::Wubot::Logger',
              'WWW::Lengthen',
              'Regexp::Common',
              'App::Wubot::Reactor::UrlLengthen',
          ) {

    eval "use $lib";
    plan skip_all => "Failed to load $lib for this test case: $@" if $@;
}

plan 'no_plan';

ok( my $lengthener = App::Wubot::Reactor::UrlLengthen->new(),
    "Creating new UrlLengthen reactor object"
);

{
    my $short_url = 'http://t.co/TlEplYw2';
    my $long_url  = 'http://www.linuxinsider.com/story/73291.html';

    is( $lengthener->react( { subject => $short_url }, { field => 'subject' }  )->{subject},
        $long_url,
        "Lengthening URL for t.co"
    );

    is ( $lengthener->cache->{$short_url},
        $long_url,
        "Checking lookup was cached"
    );

    is( $lengthener->react( { subject => $short_url }, { field => 'subject' }  )->{subject},
        $long_url,
        "Lengthening URL for t.co"
    );

}

{
    # this is a t.co that points to a plt.me
    my $short_url = 'http://t.co/2RbrtpVX',
    my $long_url  = 'https://plus.google.com/105487854388646525021/posts/CdZvFAh8te2';

    is( $lengthener->expand( $short_url ),
        $long_url,
        "Lengthening URL for plt.me"
    );

}

{
    # url that does not require shortening
    my $url = 'https://github.com/wu/';

    is( $lengthener->react( { subject => $url }, { field => 'subject' }  )->{subject},
        $url,
        "Lengthening URL that is not shortened"
    );

    is( $lengthener->expand( $url ),
        $url,
        "Lengthening URL that is not shortened"
    );

    is( $lengthener->react( { subject => $url }, { field => 'subject' }  )->{subject},
        $url,
        "Lengthening URL that is not shortened"
    );
}
