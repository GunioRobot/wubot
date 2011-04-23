package Wubot::Reactor::LessThan;
use Moose;

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

    my $field_data = $message->{ $config->{field} };

    if ( $field_data <= $config->{maximum} ) {

        $self->logger->debug( "matched => $config->{field} data $field_data less than $config->{maximum}" );

        for my $key ( keys %{ $config->{set} } ) {

            $self->logger->debug( "setting field $config->{field} to $config->{set}->{$key}" );
            $message->{ $key } = $config->{set}->{$key};

        }
    }

    return $message;
}

1;
