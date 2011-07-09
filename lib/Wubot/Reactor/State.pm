package Wubot::Reactor::State;
use Moose;

# VERSION

use YAML;

use Wubot::TimeLength;


has 'cache'   => ( is => 'ro',
                   isa => 'HashRef',
                   default => sub {
                       return {};
                   },
               );

has 'timelength' => ( is => 'ro',
                      isa => 'Wubot::TimeLength',
                      lazy => 1,
                      default => sub { return Wubot::TimeLength->new(); },
                  );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub react {
    my ( $self, $message, $config ) = @_;

    my $key        = $message->{key};
    my $field      = $config->{field};
    my $field_data = $message->{ $field } || 0;

    my $cache_data;
    if ( exists $self->cache->{ $key }->{ $field }->{value} ) {
        $cache_data = $self->cache->{ $key }->{ $field }->{value} || 0;
    }
    else {
        $cache_data = $field_data;
        $self->cache->{ $key }->{ $field }->{value} = $field_data;
        $self->cache->{ $key }->{ $field }->{lastupdate} = time;
        $message->{state_init} = 1;
        $self->logger->info( "Initialized state for $key: $field" );
    }

    my $update_cache = 0;

    unless ( $field_data == $cache_data ) {

        $message->{state_change} = $field_data - $cache_data;

        if ( $config->{increase} ) {
            if ( $message->{state_change} >= $config->{increase} ) {
                $message->{subject} = "$key: $field increased: $cache_data => $field_data";
                $message->{state_changed} = 1;
                $update_cache = 1;
            }
            elsif ( $message->{state_change} < 0 ) {
                # if we're looking for an increase, and the data
                # actually decreased, update the cache with the higher
                # value
                $update_cache = 1;
            }
        }
        elsif ( $config->{decrease} ) {
            if ( $message->{state_change} <= -$config->{decrease} ) {
                $message->{subject} = "$key: $field decreased: $cache_data => $field_data";
                $message->{state_changed} = 1;
                $update_cache = 1;
            }
            elsif ( $message->{state_change} > 0 ) {
                # if we're looking for a decrease, and the data
                # actually increased, update the cache with the higher
                # value
                $update_cache = 1;
            }
        }
        else {
            if ( abs( $message->{state_change} ) > $config->{change} ) {
                $message->{subject} = "$key: $field changed: $cache_data => $field_data";
                $message->{state_changed} = 1;
                $update_cache = 1;
            }
        }
    }

    if ( $update_cache ) {
        $self->cache->{ $key }->{ $field }->{value}      = $field_data;
    }

    $self->cache->{ $key }->{ $field }->{lastupdate} = time;

    return $message;
}

sub monitor {
    my ( $self ) = @_;

    my @react;

    my $now = time;

    for my $key ( sort keys %{ $self->cache } ) {

        for my $field ( sort keys %{ $self->cache->{$key} } ) {

            my $check_age = $now - $self->cache->{$key}->{$field}->{lastupdate};

            if ( $check_age > 600 ) {

                my $check_age_string = $self->timelength->get_human_readable( $check_age );

                my $warning = "Warning: cache data for $key:$field not updated in $check_age_string";

                $self->logger->warn( $warning );

                push @react, { key => 'wubot-reactor', subject => $warning };
            }
        }
    }

    return unless @react;

    return @react;
}

1;
