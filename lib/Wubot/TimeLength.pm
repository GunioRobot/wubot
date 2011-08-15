package Wubot::TimeLength;
use Moose;

# VERSION

use Wubot::Logger;

has 'space' => ( is => 'ro', isa => 'Bool', default => 0 );

my $constants = { s => 1,
                  m => 60,
                  h => 60*60,
                  d => 60*60*24,
                  w => 60*60*24*7,
                  M => 60*60*24*30,
                  y => 60*60*24*365,
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

    my @string;

  TIME:
    for my $time ( qw( y M w d h m s ) ) {

        if ( $time eq "s" ) {
            next TIME if $orig_seconds > $constants->{h};
        }
        elsif ( $time eq "m" ) {
            next TIME if $orig_seconds > $constants->{d};
        }
        elsif ( $time eq "h" ) {
            next TIME if $orig_seconds > $constants->{w};
        }

        my $num_seconds = $constants->{ $time };

        if ( $seconds >= $num_seconds ) {

            my $rounded = int( $seconds / $num_seconds );

            push @string, "$rounded$time";

            $seconds -= int( $num_seconds * $rounded );
        }

        last TIME unless $seconds;
    }

    my $join = "";
    if ( $self->space ) {
        $join = " ";
    }

    return $sign . join( $join, @string );
}

sub get_hours {
    my ( $self, $seconds ) = @_;

    my $num_seconds = $constants->{h};

    return int( $seconds / $num_seconds * 10 ) / 10;

}

sub get_age_color {
    my ( $self, $seconds ) = @_;

    if ( $seconds < $constants->{h} ) {
        # minutes
        my $r = $self->range_map( $seconds, $constants->{m}, $constants->{h}, 255, 110 );
        my $b = $self->range_map( $seconds, $constants->{m}, $constants->{h}, 255, 170 );
        return $self->get_hex_color( $r, 0, $b );

    }
    elsif ( $seconds < $constants->{d} ) {
        # hours
        my $r = $self->range_map( $seconds, $constants->{h}, $constants->{d},  90,  40 );
        my $g = $self->range_map( $seconds, $constants->{h}, $constants->{d}, 100,   0 );
        my $b = $self->range_map( $seconds, $constants->{h}, $constants->{d}, 255, 170 );
        return $self->get_hex_color( $r, $g, $b );
    }
    elsif ( $seconds < $constants->{M} ) {
        # days
        my $c = $self->range_map( $seconds, $constants->{d},  $constants->{M}, 240,  120 );
        return $self->get_hex_color( $c, $c, $c );
    }

    # months
    my $c = $self->range_map( $seconds, $constants->{M}, $constants->{y}, 250,  0 );
    return $self->get_hex_color( $c, $c, 0 );
}

sub get_hex_color {
    my ( $self, $r, $g, $b ) = @_;

    my $color = "#";

    for my $col ( $r, $g, $b ) {
        $color .= sprintf( "%02x", $col );
    }

    return $color;
}

sub range_map {
    my ( $self, $value, $low1, $high1, $low2, $high2 ) = @_;

    my $orig_value = $value;

    # ensure value is within low1 and high1
    if    ( $value < $low1  ) { $value = $low1  }
    elsif ( $value > $high1 ) { $value = $high1 }

    my $ratio = ( $high2 - $low2 ) / ( $high1 - $low1 );

    $value -= $low1;

    $value *= $ratio;

    $value += $low2;

    #print "MAP: $orig_value => $value [ $low1 .. $high1 ] [ $low2 .. $high2 ]\n";

    return $value;
}

1;

