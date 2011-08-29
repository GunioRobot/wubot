package Wubot::Reactor::CopyField;
use Moose;

# VERSION

use YAML;

use Wubot::Logger;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub react {
    my ( $self, $message, $config ) = @_;

    my $source;
    if ( $config->{source_field} ) {
        $source = $message->{ $config->{source_field} };
    }
    elsif ( $config->{source_field_name} ) {
        my $source_field = $message->{ $config->{source_field_name} };
        $source = $message->{ $source_field };
    }

    if ( $config->{target_field} ) {
        $message->{ $config->{target_field } } = $source;
    }
    elsif ( $config->{target_field_name} ) {
        my $target_field = $message->{ $config->{target_field_name} };
        $message->{ $target_field } = $source;
    }

    return $message;
}

1;


__END__


=head1 NAME

Wubot::Reactor::CopyField - copy the value from one field to another field


=head1 SYNOPSIS

      - name: copy value in field 'a' to field 'b'
        plugin: CopyField
        config:
          source_field: a
          target_field: b


=head1 DESCRIPTION

The CopyField plugin can be used to copy values from one field to
another field.  You can specify the name of the target field directly
in the reactor config, or you can specify the name of a field on the
message whose value is the name of the target field.

For example, consider the message:

  myfield1: foo
  myfield2: bar

The reactor rule:

      - name: copy myfield1 to myfield3
        plugin: CopyField
        config:
          source_field: myfield1
          target_field: myfield3

Would result in:

  myfield1: foo
  myfield2: bar
  myfield3: foo

If you want to use the value of a message field as the name of the
source or target fields, use source_field_name or target_field_name.
For example, this rule applied to the original data:

      - name: copy myfield1 to myfield3
        plugin: CopyField
        config:
          source_field: myfield1
          target_field_name: myfield2

This would look up the value of myfield1 in the message (foo), and set
that to the field named in myfield2 (bar):

  myfield1: foo
  myfield2: bar
  bar: foo

=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back
