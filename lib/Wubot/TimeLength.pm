package Wubot::TimeLength;
use Moose;

my $constants = { s => 1,
                  m => 60,
                  h => 60*60,
                  d => 60*60*24,
                  w => 60*60*24*7,
              };

sub get_seconds {
    my ( $self, $time ) = @_;

    my $seconds = 0;

    $time =~ s|^\+||;

    # space-separate time fields for easier split
    $time =~ s|([a-z])|$1 |;

    for my $part ( split /\s+/, $time ) {

        if ( $part =~ m|^(\-?[\d\.]+)(\w)$| && $constants->{$2} ) {
            $seconds += $1 * $constants->{$2};
        }
        elsif ( $part =~ m|^(\-?\d+)$| ) {
            $seconds += $1;
        }
        elsif ( $part =~ m|^(\w)$| && $constants->{$1} ) {
            # empty = 0 more seconds
        }
        else {
            die "ERROR: unable to parse time: $part";
        }
    }

    return $seconds;

}

sub get_human_readable {
    my ( $self, $time ) = @_;

    my $seconds = $self->get_seconds( $time );
    my $orig_seconds = $seconds;

    return '0s' unless $seconds;

    my $sign = "";
    if ( $seconds < 0 ) {
        $sign = "-";
        $seconds = -1 * $seconds;
    }

    my $string = "";

  TIME:
    for my $time ( qw( d h m s ) ) {

        if ( $time eq "s" ) {
            next TIME if $orig_seconds > $constants->{h};
        }
        elsif ( $time eq "m" ) {
            next TIME if $orig_seconds > $constants->{d};
        }

        my $num_seconds = $constants->{ $time };

        if ( $seconds >= $num_seconds ) {

            my $rounded = int( $seconds / $num_seconds );

            $string = join( "", $string, "$rounded$time" );

            $seconds -= int( $num_seconds * $rounded );
        }

        last TIME unless $seconds;
    }

    return "$sign$string";
}

sub get_hours {
    my ( $self, $seconds ) = @_;

    my $num_seconds = $constants->{h};

    return int( $seconds / $num_seconds * 10 ) / 10;

}

1;

