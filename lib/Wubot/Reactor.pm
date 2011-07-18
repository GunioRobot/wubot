package Wubot::Reactor;
use Moose;

# VERSION

use Class::Load qw/load_class/;
use Log::Log4perl;
use YAML;

has 'config' => ( is => 'ro',
                  isa => 'HashRef',
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

has 'monitors' => ( is => 'ro',
                    isa => 'HashRef',
                    default => sub { return {} },
                );

sub react {
    my ( $self, $message, $rules, $depth ) = @_;

    return $message if $message->{no_more_rules};

    $depth = $depth || 1;
    unless ( $rules ) {
        unless ( $self->config ) {
            $self->logger->logconfess( "ERROR: no reactor rules found!" );
        }
        $rules = $self->config->{rules};
    }

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

        if ( $message->{no_more_rules} ) {
            $self->logger->debug( " " x $depth, "- no_more_rules set" );
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

    $self->logger->error( "Condition could not be parsed: $condition" );
    return;
}

sub initialize_plugin {
    my ( $self, $plugin ) = @_;

    return if $self->{plugins}->{ $plugin };

    $self->logger->info( "Creating instance of reactor plugin $plugin" );
    my $reactor_class = join( "::", 'Wubot', 'Reactor', $plugin );
    load_class( $reactor_class );
    $self->{plugins}->{ $plugin } = $reactor_class->new();

    if ( $self->{plugins}->{ $plugin }->can( "monitor" ) ) {
        $self->monitors->{ $plugin } = 1;
    }

    return 1;
}

sub run_plugin {
    my ( $self, $rule, $message, $plugin, $config ) = @_;

    unless ( $message ) {
        $self->logger->logconfess( "ERROR: run_plugin called without a message" );
    }
    unless ( $plugin ) {
        $self->logger->logconfess( "ERROR: run_plugin called without a plugin" );
    }

    unless ( $self->{plugins}->{ $plugin } ) {

        $self->initialize_plugin( $plugin );
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

# walk through rules tree recursively looking for a list of the
# plugins that are used
sub find_plugins {
    my ( $self, $rules ) = @_;

    my %plugins;

    for my $rule ( @{ $rules } ) {
        if ( $rule->{plugin} ) {
            $self->logger->debug( "Found rule: $rule->{name}: $rule->{plugin}" );
            $plugins{ $rule->{plugin} } = 1;
        }

        if ( $rule->{rules} ) {
            for my $plugin ( $self->find_plugins( $rule->{rules} ) ) {
                $plugins{ $plugin } = 1;
            }
        }
    }

    return sort keys %plugins;

}

sub monitor {
    my ( $self ) = @_;

    $self->logger->debug( "Checking reactor monitors" );

    unless ( $self->{initialized_monitors} ) {
        $self->logger->warn( "Initializing monitors" );

        my @plugins = $self->find_plugins( $self->{config}->{rules} );

        for my $plugin ( @plugins ) {
            $self->initialize_plugin( $plugin );
        }

        $self->{initialized_monitors} = 1;
    }

    my @react;

    for my $plugin ( sort keys %{ $self->{monitors} } ) {

        $self->logger->debug( "Checking monitor for $plugin" );
        push @react, $self->{plugins}->{$plugin}->monitor();
    }

    return @react;
}

1;
