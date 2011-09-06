#!/perl
use strict;
use warnings;

no utf8;

use Test::More;

for my $lib ( 'HTML::Strip',
              'App::Wubot::Logger',
              'App::Wubot::Reactor::HTMLStrip' ) {

    eval "use $lib";
    plan skip_all => "Failed to load $lib for this test case" if $@;
}

plan 'no_plan';

ok( my $strip = App::Wubot::Reactor::HTMLStrip->new(),
    "Creating new console reactor object"
);

# target field tests
{
    is( $strip->react( { subject => 'test subject' }, { field => 'subject' }  )->{subject_text},
        'test subject',
        "Stripping HTML from subject with no HTML to default field_text"
    );

    is( $strip->react( { subject      => 'test subject' },
                       { field        => 'subject',
                         target_field => 'subject2'     } )->{subject},
        'test subject',
        "Stripping HTML from subject with no HTML into target_field"
    );

    is( $strip->react( { subject      => 'test subject' },
                       { field        => 'subject',
                         target_field => 'subject'      } )->{subject},
        'test subject',
        "Stripping HTML from subject with no HTML back into subject field"
    );
}

is( strip( '“foo”' ),
    '“foo”',
    "Stripping HTML from subject with no HTML"
);

is( strip( 'this is the &quot;test&quot; subject' ),
    'this is the "test" subject',
    "Stripping HTML from subject with HTML entity"
);

is( strip( 'this is wu&#8217;s subject' ),
    'this is wu’s subject',
    "Stripping HTML from subject with utf-8 HTML entity"
);

{
    my $utf_string = "\x{100}";
    utf8::encode( $utf_string );

    is( strip( "a \xc4\x80 b" ),
        "a $utf_string b",
        "Stripping HTML from subject with utf-8 encoded string"
    );

    is( strip( "a $utf_string b" ),
        "a $utf_string b",
        "Stripping HTML from subject with utf-8 decoded string"
    );

}



sub strip {
    my ( $subject ) = @_;

    my $return = $strip->react( { subject => $subject }, { field => 'subject' }  );
    return $return->{subject_text};
}

