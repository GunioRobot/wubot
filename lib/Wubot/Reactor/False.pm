package Wubot::Reactor::False;
use Moose;

# VERSION

use YAML;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub react {
    my ( $self, $message, $config ) = @_;

    unless ( $message->{ $config->{field} } ) {

        $self->logger->debug( "matched => $config->{field} is false" );

        for my $key ( keys %{ $config->{set} } ) {

            $self->logger->info( "setting field $key to $config->{set}->{$key}" );
            $message->{ $key } = $config->{set}->{$key};

        }
    }

    return $message;
}

1;


__END__


=head1 NAME

Wubot::Reactor::False - set keys and values if a field is false


=head1 DESCRIPTION

This plugin is deprecated!

Please use the 'is false' condition in combination with the 'SetField'
reactor plugin:

  - name: 'test' field does not contain a value
    condition: test is false
    plugin: SetField
    config:
      set:
        key1: value1
        key2: value2

See the 'conditions' document for more information.
