package Wubot::Reactor;
use Moose;

use Class::Load qw/load_class/;
use Log::Log4perl;
use YAML;

has 'config' => ( is => 'ro',
                  isa => 'HashRef',
                  required => 1,
              );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'plugins' => ( is => 'ro',
                   isa => 'HashRef',
                   default => sub { return {} },
               );

sub react {
    my ( $self, $message ) = @_;

    for my $rule ( @{ $self->config->{rules} } ) {

        if ( $rule->{condition} =~ m|^([\w\.]+)\s+\=\s+(.*)$| ) {
            my ( $field, $value ) = ( $1, $2 );

            if ( $message->{ $field } && $message->{ $field } eq $value ) {
                $message = $self->run_plugin( $rule->{name}, $message, $rule->{plugin}, $rule->{config} );
            }
        }
        elsif ( $rule->{condition} =~ m|^([\w\.]+)\s+\=~\s+(.*)$| ) {
            my ( $field, $value ) = ( $1, $2 );

            if ( $message->{ $field } && $message->{ $field } =~ m/$value/ ) {
                $message = $self->run_plugin( $rule->{name}, $message, $rule->{plugin}, $rule->{config} );
            }

        }
        elsif ( $rule->{condition} =~ m|^contains ([\w\.]+)$| ) {
            my $field = $1;

            if ( $message->{ $field } ) {
                $message = $self->run_plugin( $rule->{name}, $message, $rule->{plugin}, $rule->{config} );
            }

        }
    }

    return $message;
}

sub run_plugin {
    my ( $self, $rule, $message, $plugin, $config ) = @_;

    $self->logger->debug( "Rule matched: $rule" );

    unless ( $message ) {
        $self->logger->logconfess( "ERROR: run_plugin called without a message" );
    }
    unless ( $plugin ) {
        $self->logger->logconfess( "ERROR: run_plugin called without a plugin" );
    }
    unless ( $config ) {
        $self->logger->logconfess( "ERROR: run_plugin called without any config" );
    }

    unless ( $self->{plugins}->{ $plugin } ) {
        $self->logger->info( "Creating instance of reactor plugin $plugin" );
        my $reactor_class = join( "::", 'Wubot', 'Reactor', $plugin );
        load_class( $reactor_class );
        $self->{plugins}->{ $plugin } = $reactor_class->new();
    }

    my $return = $self->{plugins}->{ $plugin }->react( $message, $config );

    unless ( $return ) {
        $self->logger->error( "ERROR: plugin $plugin returned no message!" );
    }
    unless ( ref $return eq "HASH" ) {
        $self->logger->error( "ERROR: plugin $plugin returned something other than a message!" );
    }

    return $return;
}

1;
