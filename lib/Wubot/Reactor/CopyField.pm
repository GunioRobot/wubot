package Wubot::Reactor::CopyField;
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
