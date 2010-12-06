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
    my ( $self, $message, $rules, $depth ) = @_;

    return $message if $message->{no_more_rules};

    $depth = $depth || 0;
    unless ( $rules ) { $rules = $self->config->{rules} }

  RULE:
    for my $rule ( @{ $rules } ) {

        return $message if $message->{no_more_rules};

        if ( $rule->{condition} ) {
            next RULE unless $self->condition( $rule->{condition}, $message );
        }

        $self->logger->debug( " " x $depth, "- rule matched: $rule->{name}" );

        if ( $rule->{rules} ) {
            $self->react( $message, $rule->{rules}, $depth+1 );
        }

        if ( $rule->{plugin} ) {
            $message = $self->run_plugin( $rule->{name}, $message, $rule->{plugin}, $rule->{config} );
        }

        if ( $rule->{last_rule} ) {
            $message->{no_more_rules} = 1;
        }
    }

    return $message;
}

sub condition {
    my ( $self, $condition, $message ) = @_;

    if ( $condition =~ m|^(.*)\s+AND\s+(.*)$| ) {
        my ( $first, $last ) = ( $1, $2 );

        return 1 if $self->condition( $first, $message ) && $self->condition( $last, $message );
        return;
    }
    elsif ( $condition =~ m|^(.*)\s+OR\s+(.*)$| ) {
        my ( $first, $last ) = ( $1, $2 );

        return 1 if $self->condition( $first, $message ) || $self->condition( $last, $message );
        return;
    }
    elsif ( $condition =~ m|^NOT\s+(.*)$| ) {
        return if $self->condition( $1, $message );
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

    $self->logger->error( "Condition could not be parsed: $condition" );
    return;
}

sub run_plugin {
    my ( $self, $rule, $message, $plugin, $config ) = @_;

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
