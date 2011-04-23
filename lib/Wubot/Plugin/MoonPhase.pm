package Wubot::Plugin::MoonPhase;
use Moose;

# VERSION

use Astro::MoonPhase;

use Wubot::TimeLength;

has 'timelength' => ( is => 'ro',
                      isa => 'Wubot::TimeLength',
                      lazy => 1,
                      default => sub { return Wubot::TimeLength->new(); },
                  );

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $now = time;

    my ( $MoonPhase,
         $MoonIllum,
         $MoonAge,
         $MoonDist,
         $MoonAng,
         $SunDist,
         $SunAng    ) = phase( $now );

    my $message = { phase      => $MoonPhase,
                    illum      => $MoonIllum,
                    age        => $MoonAge,
                    moon_dist  => $MoonDist,
                    ang        => $MoonAng,
                    sun_dist   => $SunDist,
                    sun_ang    => $SunAng,
                };

    my @phases = phasehunt( $now );

    my $phases = { new_moon      => $phases[0],
                   first_quarter => $phases[1],
                   full_moon     => $phases[2],
                   last_quarter  => $phases[3],
               };

    my $next_phase;
    for my $phase ( keys %{ $phases } ) {
        $message->{phases}->{$phase}->{until} = int( $phases->{ $phase } - $now );
        next if $phases->{ $phase } < $now;
        next if $next_phase && $phases->{$phase} > $phases->{$next_phase};
        $next_phase = $phase;
    }

    my $next_until = $self->timelength->get_human_readable( $message->{phases}->{$next_phase}->{until} );
    $message->{subject} = "$next_until until $next_phase";

    return { react => $message, cache => $message };
}

1;
