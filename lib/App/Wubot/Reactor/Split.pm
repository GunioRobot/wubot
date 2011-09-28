package App::Wubot::Reactor::Split;
use Moose;

# VERSION

use App::Wubot::Logger;

sub react {
    my ( $self, $message, $config ) = @_;

    return $message unless $config->{source_field};

    my @data = split /\s*,\s*/, $message->{ $config->{source_field} };

    for my $field ( reverse @{ $config->{target_fields} } ) {
        $message->{ $field } = pop @data;
    }

    return $message;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

App::Wubot::Reactor::Split - split a CSV field on a message out into multiple other fields

=head1 SYNOPSIS

  - name: split
    plugin: Split
    config:
      source_field: line
      target_fields:
        - source
        - type
        - value
        - units


=head1 DESCRIPTION

TODO: More to come...


=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back
