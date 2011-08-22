package Wubot::Web::Graphs;
use Mojo::Base 'Mojolicious::Controller';

sub graphs {
    my $self = shift;

    my $graphs = [
        { sensors => [
            "http://wubot/wubot/graphs/Coopduino.now.png",
            "http://wubot/wubot/graphs/Coopduino.png",
            "http://wubot/wubot/graphs/Coopduino-week.png",
            "http://wubot/wubot/graphs/Growbot.png",
        ] },
        { 'sensor-monthly' => [
            "http://wubot/wubot/graphs/outside-temp/outside-temp-monthly.png",
            "http://wubot/wubot/graphs/lab-temp/lab-temp-monthly.png",
            "http://wubot/wubot/graphs/coop-temp/coop-temp-monthly.png",
            "http://wubot/wubot/graphs/growbot-temp/growbot-temp-monthly.png",
            "http://wubot/wubot/graphs/growbot-moisture/growbot-moisture-monthly.png",
            "http://wubot/wubot/graphs/growbot-humidity/growbot-humidity-monthly.png",
        ] },
        { external => [
            "http://wubot/wubot/graphs/WebFetch-qwest/WebFetch-qwest-daily.png",
            "http://wubot/wubot/graphs/Ping-google/Ping-google-daily.png",
            "http://wubot/wubot/graphs/Ping.png",
            "http://wubot/wubot/graphs/Ping-router/Ping-router-daily.png",
        ] },
        { navi => [
            "http://wubot/wubot/graphs/Uptime-navi/Uptime-navi-daily.png",
            "http://wubot/wubot/graphs/Command-netstat-navi/Command-netstat-navi-daily.png",
            "http://wubot/wubot/graphs/OsxIdle-navi/OsxIdle-navi-daily.png",
            "http://wubot/wubot/graphs/OsxIdle-navi/OsxIdle-navi-weekly.png",
            "http://wubot/wubot/graphs/WorkHours-navi/WorkHours-navi-daily.png",
            "http://wubot/wubot/graphs/WorkHours-navi/WorkHours-navi-weekly.png",
        ] },
        { geektank => [
            "http://wubot/wubot/graphs/Uptime-bsd-01/Uptime-bsd-01-daily.png",
            "http://wubot/wubot/graphs/Uptime-bsd-02/Uptime-bsd-02-daily.png",
            "http://wubot/wubot/graphs/Uptime-bsd-03/Uptime-bsd-03-daily.png",
            "http://wubot/wubot/graphs/Uptime-navi2/Uptime-navi2-daily.png",
            "http://wubot/wubot/graphs/Uptime-homework/Uptime-homework-daily.png",
        ] },
        { geekfarm => [
            "http://wubot/wubot/graphs/FileRegexp-mail-rootbsd/FileRegexp-mail-rootbsd-daily.png",
            "http://wubot/wubot/graphs/FileRegexp-mail-rootbsd/FileRegexp-mail-rootbsd-monthly.png",
            "http://wubot/wubot/graphs/Uptime-rootbsd/Uptime-rootbsd-daily.png",
            "http://wubot/wubot/graphs/Uptime-geekfarm/Uptime-geekfarm-daily.png",
            "http://wubot/wubot/graphs/Ping-google-rootbsd/Ping-google-rootbsd-daily.png",
        ] },
        { weather => [
          "http://image.weather.com/images/maps/current/acttemp_600x405.jpg",
          "http://image.weather.com/images/maps/current/actheat_600x405.jpg",
          "http://image.weather.com/web/radar/us_radar_plus_usen.jpg",
          "http://image.weather.com/images/maps/boat-n-beach/us_wind_cur_600x405.jpg",
          "http://image.weather.com/images/maps/special/norm_dep_hi_600x405.jpg",
          "http://image.weather.com/images/maps/special/norm_dep_low_600x405.jpg",
          "http://image.weather.com/images/maps/severe/map_light_ltst_4namus_enus_600x405.jpg",
          "http://image.weather.com/images/maps/current/actchill_600x405.jpg",
          "http://squall.sfsu.edu/gif/jetstream_init_00.gif",
        ] },
    ];

    my $search_key = $self->param( 'key' ) || "sensors";

    my @nav;
    my @png;
    for my $graph ( @{ $graphs } ) {
        my ( $key ) = keys %{ $graph };
        push @nav, $key;

        if ( $search_key && $search_key eq $key ) {
            for my $png ( @{ $graph->{$key} } ) {
                push @png, $png;
            }
        }
    }

    $self->stash( 'nav', \@nav );
    $self->stash( 'images', \@png );

    $self->render( template => 'graphs' );

};

1;
