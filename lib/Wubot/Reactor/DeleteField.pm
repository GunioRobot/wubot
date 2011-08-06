package Wubot::Reactor::DeleteField;
use Moose;

# VERSION

sub react {
    my ( $self, $message, $config ) = @_;

    delete $message->{ $config->{field} };

    return $message;
}

1;

__END__


=head1 NAME

Wubot::Reactor::DeleteField - remove a field from the message


=head1 SYNOPSIS

      - name: delete field 'x' from the message
        plugin: DeleteField
        config:
          field: x


=head1 DESCRIPTION

Removes a field and its value from a message.
