package Wubot::TimeLength;
use Moose;

# VERSION

use Wubot::Logger;

=head1 NAME

Wubot::TimeLength - utilities for dealing with time durations


=head1 SYNOPSIS

    use Wubot::TimeLength;

    my $timelength = Wubot::TimeLength->new();

    # returns '1h1m'
    $timelength->get_human_readable( 3601 );

    # returns 1.5
    $timelength->get_hours( 60*60*1.5 );

    # returns 3601
    $timelength->get_seconds( '1h1s' );

    # rounds 1.5 days, 1 minute, and 10 seconds to nearest hour: 1d12h
    $timelength->get_human_readable( 60*60*24*1.5+70 )

    # use a space delimiter
    my $timelength = Wubot::TimeLength->new( space => 1 ),

    # returns '1h 1s' with space delimiter
    $timelength->get_human_readable( 3601 );


=head1 DESCRIPTION

This class provides some utilities for dealing with time durations.
It supports the 'compact' form used by L<Convert::Age>, but with a few
variations.

For the sake of simplicity, one month is always treated as 30 days,
and one year is always represented as 365 days.

=cut

has 'space' => ( is => 'ro', isa => 'Bool', default => 0 );

my $constants = { s => 1,
                  m => 60,
                  h => 60*60,
                  d => 60*60*24,
                  w => 60*60*24*7,
                  M => 60*60*24*30,
                  y => 60*60*24*365,
              };

=head1 SUBROUTINES/METHODS

=over 8

=item $obj->get_seconds( $time );

When given a date in the 'compact' form (e.g. '1h1m' or '1h 1m'),
returns the number of seconds.

=cut

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

=item $obj->get_human_readable( $seconds );

Given a number of seconds, return the time in 'compact' form.  For
example, '3601' seconds returns '1h1s'.

Time lengths are rounded to the most significant two fields.  For
example, 1 day, 1 hour, 1 minute, and 1 second would be rounded to
1d1h.  Obviously this method is not intended for precise time
calculations, but rather for human-friendly ones.  Please don't try to
convert a number of seconds to the human-readable format, and then
convert that back to a number of seconds, as it will most likely be
different due to rounding!!! If you need a more precise calculation,
use L<Convert::Age>.

If the 'space' option was set at construction time, then a space
delimiter will be used in the resulting string, e.g. '1h 1m'.

=cut

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

=item $obj->get_hours( $seconds )

Given a number of seconds, return the number of hours rounded to a
single digit.

=cut

sub get_hours {
    my ( $self, $seconds ) = @_;

    my $num_seconds = $constants->{h};

    return int( $seconds / $num_seconds * 10 ) / 10;

}

=item $obj->get_age_color( $seconds )

Given a number of seconds, return a color representing the age.  This
helps to very quickly assess the age of an item by looking at the
color.  A steady stream of items with evenly spaced ages will create a
smooth gradient of color.  Different colors are used to represent the
age in minutes, hours, days, or months.

If the age is younger than 1 hour, the color will be somewhere in the
spectrum from light pink (brand new) to dark purple (1 hour old).

If the age is between 1 hour and 1 day old, the color will vary from
light blue to dark blue.

If the age is between 1 day and 1 month, the color will vary from a
rather light gray to black.

If the age is greater than 1 month year, the color will be an
increasingly dark yellow color.

This should be configurable in the future.

=cut

sub get_age_color {
    my ( $self, $seconds ) = @_;

    if ( $seconds < $constants->{h} ) {
        # minutes
        my $r = $self->_range_map( $seconds, $constants->{m}, $constants->{h}, 255, 110 );
        my $b = $self->_range_map( $seconds, $constants->{m}, $constants->{h}, 255, 170 );
        return $self->_get_hex_color( $r, 0, $b );

    }
    elsif ( $seconds < $constants->{d} ) {
        # hours
        my $r = $self->_range_map( $seconds, $constants->{h}, $constants->{d},  90,  40 );
        my $g = $self->_range_map( $seconds, $constants->{h}, $constants->{d}, 100,   0 );
        my $b = $self->_range_map( $seconds, $constants->{h}, $constants->{d}, 255, 170 );
        return $self->_get_hex_color( $r, $g, $b );
    }
    elsif ( $seconds < $constants->{M} ) {
        # days
        my $c = $self->_range_map( $seconds, $constants->{d},  $constants->{M}, 240,  120 );
        return $self->_get_hex_color( $c, $c, $c );
    }

    # months
    my $c = $self->_range_map( $seconds, $constants->{M}, $constants->{y}, 250,  0 );
    return $self->get_hex_color( $c, $c, 0 );
}

sub _get_hex_color {
    my ( $self, $r, $g, $b ) = @_;

    my $color = "#";

    for my $col ( $r, $g, $b ) {
        $color .= sprintf( "%02x", $col );
    }

    return $color;
}

sub _range_map {
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

=back

=head1 SEE ALSO

L<Convert::Age>


