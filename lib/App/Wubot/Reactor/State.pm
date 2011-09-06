package App::Wubot::Reactor::State;
use Moose;

# VERSION

use File::Path;
use YAML;

use App::Wubot::Logger;
use App::Wubot::Util::TimeLength;

has 'cache'   => ( is => 'ro',
                   isa => 'HashRef',
                   default => sub {
                       return {};
                   },
               );

has 'timelength' => ( is => 'ro',
                      isa => 'App::Wubot::Util::TimeLength',
                      lazy => 1,
                      default => sub { return App::Wubot::Util::TimeLength->new(); },
                  );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'cachedir' => ( is => 'ro',
                    isa => 'Str',
                    lazy => 1,
                    default => sub {
                        my $dir = join( "/", $ENV{HOME}, "wubot", "state" );
                        unless ( -d $dir ) { mkpath( $dir ) };
                        return $dir;
                    },
                );

sub react {
    my ( $self, $message, $config ) = @_;

    my $key        = $message->{key};
    my $field      = $config->{field};
    my $field_data = $message->{ $field } || 0;

    my $filename = join( ".", join( "_", $key, $field ), "yaml" );
    $filename =~ s|[^\w\d\_\-\.]+|_|;

    my $cache_file = join( "/", $self->cachedir, $filename );
    $self->logger->debug( "State cache file: $cache_file" );

    my $cache;
    my $lastvalue;

    if ( -r $cache_file ) {
        $cache = YAML::LoadFile( $cache_file );
    }

    if ( $config->{notify_interval} ) {
        $cache->{ $key }->{ $field }->{notify_interval} = $config->{notify_interval};
    }

    if ( exists $cache->{ $key }->{ $field }->{value} ) {
        $lastvalue = $cache->{ $key }->{ $field }->{value} || 0;
    }
    else {
        $lastvalue = $field_data;
        $cache->{ $key }->{ $field }->{value} = $field_data;
        $cache->{ $key }->{ $field }->{lastupdate} = $message->{lastupdate} || time;
        $message->{state_init} = 1;
        $self->logger->info( "Initialized state for $key: $field" );
    }

    my $update_cache = 0;
    my $changed_flag = 0;

    unless ( $field_data == $lastvalue ) {

        $message->{state_change} = $field_data - $lastvalue;

        my $cache_age_string = "";

        if ( $cache->{ $key }->{ $field }->{lastchange} ) {

            $cache_age_string
                = $self->timelength->get_human_readable(
                    time - $cache->{ $key }->{ $field }->{lastchange}
                );

            $cache_age_string = " ($cache_age_string)";
        }

        if ( $config->{increase} ) {
            if ( $message->{state_change} >= $config->{increase} ) {
                $message->{subject} = "$key: $field increased: $lastvalue => $field_data$cache_age_string";
                $message->{state_changed} = 1;
                $update_cache = 1;
                $changed_flag = 1;
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
                $message->{subject} = "$key: $field decreased: $lastvalue => $field_data$cache_age_string";
                $message->{state_changed} = 1;
                $update_cache = 1;
                $changed_flag = 1;
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
                $message->{subject} = "$key: $field changed: $lastvalue => $field_data$cache_age_string";
                $message->{state_changed} = 1;
                $update_cache = 1;
                $changed_flag = 1;
            }
        }
    }

    if ( $update_cache ) {
        $cache->{ $key }->{ $field }->{value}      = $field_data;
    }

    if ( $changed_flag ) {
        $cache->{ $key }->{ $field }->{lastchange} = $message->{lastupdate} || time;
    }

    $cache->{ $key }->{ $field }->{lastupdate} = $message->{lastupdate} || time;

    YAML::DumpFile( $cache_file, $cache );

    return $message;
}

sub monitor {
    my ( $self ) = @_;

    my @react;

    my $now = time;

    my $directory = $self->cachedir;

    my $dir_h;
    opendir( $dir_h, $directory ) or die "Can't opendir $directory: $!";

  FILE:
    while ( defined( my $entry = readdir( $dir_h ) ) ) {
        next unless $entry && $entry =~ m|\.yaml$|;

        my $cache = YAML::LoadFile( "$directory/$entry" );

      KEY:
        for my $key ( sort keys %{ $cache } ) {

          FIELD:
            for my $field ( sort keys %{ $cache->{$key} } ) {

                my $check_age = $now - $cache->{$key}->{$field}->{lastupdate};

                if ( $check_age > 600 ) {

                    my $notify_interval = $cache->{$key}->{$field}->{notify_interval};
                    if ( $notify_interval ) {

                        my $interval = $self->timelength->get_seconds( $notify_interval );
                        $self->logger->debug( "Checking notify_interval: $notify_interval: $interval" );

                        my $last_notify = $cache->{$key}->{$field}->{last_notify} || 0;
                        my $notify_age = $now - $last_notify;

                        if ( $last_notify && $notify_age < $interval ) {
                            $self->logger->debug( "Suppressing notification, last=$notify_age, interval=$interval" );
                            next FIELD;
                        }

                        $cache->{$key}->{$field}->{last_notify} = $now;
                        YAML::DumpFile( "$directory/$entry", $cache );
                    }

                    my $check_age_string = $self->timelength->get_human_readable( $check_age );
                    my $warning = "Warning: cache data for $key:$field not updated in $check_age_string";
                    $self->logger->warn( $warning );

                    push @react, { key => $key, subject => $warning, lastupdate => $now };

                }
            }
        }


    }
    closedir( $dir_h );


    return unless @react;

    return @react;
}

1;

__END__

=head1 NAME

App::Wubot::Reactor::State - monitor the state of message fields over time

=head1 DESCRIPTION

TODO: More to come...


=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=item monitor()

The standard reactor monitor() method.

=back
