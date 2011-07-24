package Wubot::Reactor::SetField;
use Moose;

# VERSION

use Log::Log4perl;
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

    if ( $config->{field} ) {

        if ( $config->{no_override} ) {
            return $message if $message->{ $config->{field} };
        }

        $message->{ $config->{field} } = $config->{value};
    }
    elsif ( $config->{set} ) {

      KEY:
        for my $key ( keys %{ $config->{set} } ) {

            next KEY if $config->{no_override} && $message->{ $key };

            $message->{ $key } = $config->{set}->{ $key };

        }

    }
    else {
        $self->logger->warn( "ERROR: No 'field' or 'set' in SetField config: ", YAML::Dump $config );
    }


    return $message;
}

1;

__END__


=head1 NAME

Wubot::Reactor::SetField - set one or more fields on the message to a configured value


=head1 SYNOPSIS

  - name: set x to 123
    plugin: SetField
    config:
      field: x
      value: 123


  - name: set x to 123, y to 456, and z to 789
    plugin: SetField
    config:
      set:
        x: 123
        y: 456
        z: 789
