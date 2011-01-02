#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';

use Wubot::Logger;
use Wubot::Util::XMLTV;

my $tempdir      = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
my $dbfile_new   = join( "/", $tempdir, "test.sql" );
my $dbfile_test  = "t/xmltv/test.sql";

ok( my $tv = Wubot::Util::XMLTV->new( { dbfile => $dbfile_test } ),
    "Creating a new Wubot::Util::XMLTV object"
);

my $datafile = "t/xmltv/dd-data.xml";

#ok( $tv->process_data( $datafile ),
#    "Processing XML data"
#);

#system( 'cp', $dbfile_new, $dbfile_test );

is_deeply( [ $tv->get_series_id( 'Futurama' ) ],
           [ 'EP00303483' ],
           "Getting futurama series id"
       );

is_deeply( [ $tv->get_program_id( 'Futurama' ) ],
           [ qw( EP003034830009 EP003034830019 EP003034830073 EP003034830079 EP003034830080
                 EP003034830081 EP003034830082 EP003034830091 EP003034830097
           )
         ],
           "Getting futurama program ids"
       );

is( ( $tv->get_program_details( 'EP003034830009' ) )[0]->{date},
    '1999-04-27',
    "Getting program details for a single episode of futurama: date"
);

is( ( $tv->get_program_details( 'EP003034830009' ) )[0]->{description},
    'Fry discovers that 1,000 years worth of interest has made him a billionaire. Voices of Billy West and Katey Sagal. Guest voice: Pamela Anderson Lee.',
    "Getting program details for a single episode of futurama: description"
);

is( ( $tv->get_program_details( 'EP003034830009' ) )[0]->{title},
    'Futurama',
    "Getting program details for a single episode of futurama: title"
);

is( ( $tv->get_program_details( 'EP003034830009' ) )[0]->{subtitle},
    'A Fishful of Dollars',
    "Getting program details for a single episode of futurama: subtitle"
);

is( ( $tv->get_program_details( 'EP003034830009' ) )[0]->{show_type},
    'Series',
    "Getting program details for a single episode of futurama: type = series"
);

is( ( $tv->get_station( { callsign => 'TOONP' } ) )[0]->{station_id},
    18151,
    "Getting station_id for TOONP"
);

is( ( $tv->get_station( { callsign => 'TOONP' } ) )[0]->{name},
    'Cartoon Network (Pacific)',
    "Getting name for TOONP"
);

is( ( $tv->get_program_crew( 'EP003034830009' ) )[7]->{role},
    'Executive Producer',
    "Checking executive producer role"
);
is( ( $tv->get_program_crew( 'EP003034830009' ) )[7]->{givenname},
    'Matt',
    "Checking executive producer first name"
);
is( ( $tv->get_program_crew( 'EP003034830009' ) )[7]->{surname},
    'Groening',
    "Checking executive producer last name"
);

# is_deeply( { $tv->get_roles( "Matt", "Groening" ) },
#            { Futurama => 9, 'The Simpsons' => 4 },
#            "Checking roles for Matt Groening"
#        );

is_deeply( [ $tv->get_program_genres( 'EP003034830009' ) ],
           [ 'Sitcom', 'Science fiction', 'Animated' ],
           "Checking program genres"
       );

ok( ! $tv->get_score( 'EP003034830009' ),
    "Checking program has no score"
);

ok( $tv->set_score( 'EP003034830009', 5 ),
    "Setting program score to 5"
);

is( $tv->get_score( 'EP003034830009' ),
    5,
    "Checking program score was set"
);

ok( $tv->set_score( 'EP003034830009', undef ),
    "Setting program score back to 'undef'"
);

ok( ! $tv->get_score( 'EP003034830009' ),
    "Checking program score is unset"
);

ok( $tv->get_schedule( { start => 1293839700, limit => 1 } ),
    "Getting next program scheduled in the future"
);

is( $tv->get_station_id( '33' ),
    10139,
    "Checking lookup of station_id from channel number"
);

is( $tv->get_channel( '10139' ),
    33,
    "Checking lookup of channel from station id"
);

{
    my ( $show ) = $tv->get_schedule( { start => 1293839700, limit => 1 } );
    is( $show->{program_id},
        'SH013568520000',
        "Checking that get_schedule got the next scheduled item"
    );
}

is( $tv->is_station_hidden( '10139' ),
    0,
    "Checking that station is not hidden"
);

ok( $tv->hide_station( '10139', 1 ),
    "Hiding station"
);

is( $tv->is_station_hidden( '10139' ),
    1,
    "Checking that station is hidden"
);

{
    my ( $show ) = $tv->get_schedule( { start => 1293839700, limit => 1 } );
    isnt( $show->{program_id},
          'SH013568520000',
          "Checking that get_schedule ignored entry on hidden channel"
      );
}

ok( $tv->hide_station( '10139', 0 ),
    "Unhiding station"
);

is( $tv->is_station_hidden( '10139' ),
    0,
    "Checking that station is unhidden"
);


{
    my ( $show ) = $tv->get_schedule( { start => 1293839700, limit => 1 } );
    is( $show->{program_id},
        'SH013568520000',
        "Checking that get_schedule got the item from unhidden channel"
    );
}

{
    my ( $show ) = $tv->get_schedule( { start => 1293839700, limit => 1, channel => '36' } );
    is( $show->{program_id},
        'SH012460860000',
        "Checking that get_schedule got the next scheduled item on channel 36"
    );

    is( $show->{channel},
        '36',
        "Checking that 'channel' was set in the schedule entry"
    );

    is( $show->{channel_name},
        'Cable News Network',
        "Checking channel name set in schedule entry"
    );

    is( $show->{title},
        'John King, USA',
        "Checking program title"
    );

    print YAML::Dump $show;
}



