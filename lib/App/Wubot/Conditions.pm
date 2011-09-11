package App::Wubot::Conditions;
use Moose;

# VERSION

use Scalar::Util qw/looks_like_number/;

use App::Wubot::Logger;

=head1 NAME

App::Wubot::Conditions - evaluation conditions on reactor rules


=head1 SYNOPSIS

    use App::Wubot::Conditions;

    my $cond = App::Wubot::Conditions->new();

    # prints 'OK'
    print "OK\n" if $cond->istrue( "foo equals 5", { foo => 5 } );


=head1 DESCRIPTION

There are a number of conditions that are available for the rules:

  - {fieldname} equals {value}
    - values of field {fieldname} on the message equals the specified value

  - {fieldname} matches {regexp}
    - value of field {fieldname} matches specified regexp

  - {fieldname} imatches {regexp}
    - case insensitve regexp match

  - contains {fieldname}
    - the message contains the field, the value of the field may be undefined or 0

  - {fieldname} is false
    - the field has a value that is false according to perl, i.e. undef, 0, or ""

  - {fieldname} is true
    - the field has a value which is true according to perl, i.e. not undef, 0, or ""

You can also make numeric comparisons between fields and values or
fields and other fields.

  - operators: <, <=, >, >=,
    - {fieldname} {operator} {value}
    - {fieldname} {operator} {fieldname}

  - examples:
    - size > 300
    - heatindex > temperature

Any rule can be prefixed by NOT, as in:

  - NOT title matches foo
    - true unless the title contains 'foo'

You can string together multiple rules using AND and OR.  You MUST
capitalize the "AND" and "OR" or else the rule will not be parsed
properly.

  - subject is true AND body is true
    - true if the subject and body are populated

  - title matches foo OR body matches foo
    - true if the title or body contains the string 'foo'

  - NOT title matches foo AND NOT body matches foo
    - true as long as 'foo' does not occur in either the title or body


=cut

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

=head1 SUBROUTINES/METHODS

=over 8

=item istrue( $condition, $message )

Process conditions on the specified message.  Returns a true value if
the message satisfies the condition.

=cut

sub istrue {
    my ( $self, $condition, $message ) = @_;

    return unless $condition;

    if ( $condition =~ m|^(.*)\s+AND\s+(.*)$| ) {
        my ( $first, $last ) = ( $1, $2 );

        return 1 if $self->istrue( $first, $message ) && $self->istrue( $last, $message );
        return;
    }
    elsif ( $condition =~ m|^(.*)\s+OR\s+(.*)$| ) {
        my ( $first, $last ) = ( $1, $2 );

        return 1 if $self->istrue( $first, $message ) || $self->istrue( $last, $message );
        return;
    }
    elsif ( $condition =~ m|^NOT\s+(.*)$| ) {
        return if $self->istrue( $1, $message );
        return 1;
    }
    elsif ( $condition =~ m|^([\w\.]+)\s+equals\s+(.*)$| ) {
        my ( $field, $value ) = ( $1, $2 );

        return 1 if $message->{ $field } && $message->{ $field } eq $value;
        return;
    }
    elsif ( $condition =~ m|^([\w\.]+)\s+matches\s+(.*)$| ) {
        my ( $field, $value ) = ( $1, $2 );

        return 1 if $message->{ $field } && $message->{ $field } =~ m/$value/;
        return;
    }
    elsif ( $condition =~ m|^([\w\.]+)\s+imatches\s+(.*)$| ) {
        my ( $field, $value ) = ( $1, $2 );

        return 1 if $message->{ $field } && $message->{ $field } =~ m/$value/i;
        return;
    }
    elsif ( $condition =~ m|^contains ([\w\.]+)$| ) {
        my $field = $1;

        return 1 if exists $message->{ $field };
        return;
    }
    elsif ( $condition =~ m|^([\w\.]+) is true$| ) {
        my $field = $1;

        if ( $message->{ $field } ) {
            return if $message->{ $field } eq "false";
            return 1;
        }
        return;
    }
    elsif ( $condition =~ m|^([\w\.]+) is false$| ) {
        my $field = $1;

        return 1 unless $message->{$field};
        return 1 if $message->{ $field } eq "false";
        return;
    }
    elsif ( $condition =~ m/^([\w\d\.\_]+) ((?:>|<)=?) ([\w\d\.\_]+)$/ ) {
        my ( $left, $op, $right ) = ( $1, $2, $3 );

        my $first;
        if ( looks_like_number( $left ) ) {
            $first = $left;
        }
        else {
            return unless exists $message->{$left};
            $first = $message->{$left};
            return unless looks_like_number( $first )
        }

        my $second;
        if ( looks_like_number( $right ) ) {
            $second = $right;
        }
        else {
            return unless exists $message->{$right};
            $second = $message->{$right};
            return unless looks_like_number( $second )
        }

        if ( $op eq ">" ) {
            return 1 if $first > $second;
        }
        elsif ( $op eq ">=" ) {
            return 1 if $first >= $second;
        }
        elsif ( $op eq "<" ) {
            return 1 if $first < $second;
        }
        elsif ( $op eq "<=" ) {
            return 1 if $first <= $second;
        }

        return;
    }

    $self->logger->error( "Condition could not be parsed: $condition" );
    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=back

=head1 LIMITATIONS

Unfortunately you can not (yet) use parens within conditions.
Conditions are evaluated from left to right in order, e.g.

  - x is true AND y is true OR z is true
    - evaluates as: x is true AND ( y is true OR z is true )

The main mechanism for nesting conditions is to use rule trees.  Child
rules are only evaluated if the parent rule matches, so parent and
child rules are logically combined by AND.  For example, set the field
'foo' to the value '1' based on the following logic:

  ( x is true OR y is true ) AND ( a is true OR b is true )

You could create the following rule tree:

  rules:
    - name: check x and y
      condition: x is true OR y is true
      rules:
        - name: check a and b
          condition: a is true OR b is true
          plugin: SetField
          config:
            field: foo
            value: 1

=head1 PERFORMANCE

The performance of this library is not great, owing to the fact that
it is currently a huge if-then block of regular expressions that try
to parse each condition on every run.  I have several ideas about how
to make this more efficient.  The performance will improve in the
future.

