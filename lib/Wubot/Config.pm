package Wubot::Config;
use Moose;

# VERSION

use Log::Log4perl;
use Sys::Hostname qw();
use YAML;

has 'hostname' => ( is => 'ro',
                    isa => 'Str',
                    lazy => 1,
                    default => sub {
                        my $hostname = Sys::Hostname::hostname();
                        $hostname =~ s|\..*$||;
                        return $hostname;
                    },
                );

has 'root'   => ( is      => 'ro',
                  isa     => 'Str',
                  required => 1,
              );

has 'config' => ( is      => 'ro',
                  isa     => 'HashRef',
                  default => sub { $_[0]->read_config() },
              );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub read_config {
    my ( $self ) = @_;

    $self->logger->info( "Reading configuration!" );

    my $config = {};

    my $hostname = $self->hostname;

    # monitor plugins
    {
        my $directory = join( "/", $self->root, "plugins" );

        unless ( -d $directory ) {
            die "ERROR: config root directory does not exist: $directory\n";
        }

        my $mod_dir_h;
        opendir( $mod_dir_h, $directory ) or die "Can't opendir $directory: $!";

      MODULES:
        while ( defined( my $plugin = readdir( $mod_dir_h ) ) ) {
            next unless $plugin;
            next if $plugin =~ m|^\.|;

            my $plugin_dir = "$directory/$plugin";

            next unless -d $plugin_dir;

            $self->logger->debug( "Reading plugin directory: $plugin" );

            my $instance_dir_h;

            opendir( $instance_dir_h, $plugin_dir ) or die "Can't opendir $plugin_dir: $!";

            my $instance_count = 0;

          INSTANCES:
            while ( defined( my $instance_entry = readdir( $instance_dir_h ) ) ) {
                next unless $instance_entry;

                next unless $instance_entry =~ m|.yaml(?:\.$hostname)?$|;
                next if -d "$plugin_dir/$instance_entry";
                next if $instance_entry =~ m|^\.|;

                $self->logger->debug( "\tReading instance config: $instance_entry" );

                my $key = join( "-", $plugin, $instance_entry );
                $key =~ s|\.yaml.*$||;

                my $instance_config = YAML::LoadFile( "$plugin_dir/$instance_entry" );
                $instance_config->{plugin} = "Wubot::Plugin::$plugin";

                $config->{$key} = { file   => $instance_entry,
                                    dir    => $plugin,
                                    config => $instance_config,
                                    key    => $key,
                                };

                $instance_count++;
            }

            if ( $instance_count ) {
                $self->logger->info( "Config: loaded $instance_count instance(s) of $plugin" );
            }

            closedir( $instance_dir_h );
        }

        closedir( $mod_dir_h );
    }

    return $config;
}

sub get_plugins {
    my ( $self ) = @_;

    my @plugins;

    for my $plugin ( sort keys %{ $self->config } ) {

        push @plugins, $self->config->{$plugin}->{key};
    }

    return @plugins;
}

sub get_plugin_config {
    my ( $self, $plugin, $param ) = @_;

    unless ( $self->config->{$plugin} ) {
        die "ERROR: no config found for plugin $plugin";
    }

    unless ( $param ) {
        return $self->config->{$plugin}->{config};
    }

    unless ( $self->config->{$plugin}->{config}->{$param} ) {
        warn "ERROR: config param $param not found for plugin $plugin";
        return;
    }

    return $self->config->{$plugin}->{config}->{$param};
}

1;
