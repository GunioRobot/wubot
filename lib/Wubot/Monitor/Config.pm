package Wubot::Monitor::Config;
use Moose;

use YAML;

has 'root'   => ( is      => 'ro',
                  isa     => 'Str',
                  required => 1,
              );

has 'config' => ( is      => 'ro',
                  isa     => 'HashRef',
                  default => sub { $_[0]->read_config() },
              );

sub read_config {
    my ( $self ) = @_;

    print "Reading configuration!\n";

    my $config = {};

    my $directory = $self->root;

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

        print "Reading plugin directory: $plugin\n";

        my $instance_dir_h;

        opendir( $instance_dir_h, $plugin_dir ) or die "Can't opendir $plugin_dir: $!";

      INSTANCES:
        while ( defined( my $instance_entry = readdir( $instance_dir_h ) ) ) {
            next unless $instance_entry;

            next if -d "$plugin_dir/$instance_entry";
            next if $instance_entry =~ m|^\.|;

            print "\tReading instance config: $instance_entry\n";

            my $key = join( "-", $plugin, $instance_entry );
            $key =~ s|.yaml$||;

            my $instance_config = YAML::LoadFile( "$plugin_dir/$instance_entry" );
            $instance_config->{plugin} = "Wubot::Monitor::Plugin::$plugin";

            $config->{$key} = { file   => $instance_entry,
                                dir    => $plugin,
                                config => $instance_config,
                                key    => $key,
                            };
        }

        closedir( $instance_dir_h );
    }

    closedir( $mod_dir_h );

    return $config;
}

sub get_monitors {
    my ( $self ) = @_;

    my @monitors;

    for my $monitor ( sort keys %{ $self->config } ) {

        push @monitors, $self->config->{$monitor}->{key};
    }

    return @monitors;
}

sub get_monitor_config {
    my ( $self, $monitor, $param ) = @_;

    unless ( $self->config->{$monitor} ) {
        die "ERROR: no config found for monitor $monitor";
    }

    unless ( $param ) {
        return $self->config->{$monitor}->{config};
    }

    unless ( $self->config->{$monitor}->{config}->{$param} ) {
        warn "ERROR: config param $param not found for monitor $monitor";
        return;
    }

    return $self->config->{$monitor}->{config}->{$param};
}

1;
