package Wubot::Plugin::Ping;
use Moose;

# VERSION

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    my $host        = $config->{host};
    my $num_packets = $config->{num_packets} || 1;
    my $command     = $config->{command}     || "ping -c $num_packets";

    my $rt;

    for my $line ( split /\n/, `$command $host 2>&1` ) {
        chomp $line;
        next unless $line;

        if ( $line =~ m|icmp_seq\=(\d+)| ) {
            my $icmp_seq = $1;
            $line =~ m|time\=([\d\.]+)|;
            my $time = $1;
            $rt->{$icmp_seq} = $time;
        }
        else {
            next if $line =~ m/data bytes|statistics|packets transmitted|round-trip/;
            $self->logger->warn( "Can't parse output of ping command: $line" );
        }
    }

    my $count_received = scalar ( keys %{ $rt } );

    my $average = 0;
    for my $icmp_seq ( keys %{ $rt } ) {
        $average += $rt->{$icmp_seq};
    }
    if ( $average ) { $average = int ( $average / $count_received * 100 ) / 100 }

    my $loss = $num_packets - $count_received;

    my $reaction = { host    => $config->{host},
                     count   => $num_packets,
                     average => $average,
                     loss    => $loss,
                 };

    if ( $loss == $num_packets ) {
        $reaction->{subject} = "Unable to ping host: $config->{host}";
    }

    return { react => $reaction };
}

1;

__END__

=head1 NAME

Wubot::Plugin::Ping - monitor ping response from a remote host

=head1 SYNOPSIS

  ~/wubot/config/plugins/Ping/google.yaml.bsd-02

  ---
  host: google.com
  num_packets: 3
  delay: 5m

=head1 DESCRIPTION

Monitor the ping response time and number of packets dropped from a
remote host.

The generated message will contain:

  host: remote host name/ip from configuration
  count: number of packets transmitted
  average: average ping response time
  loss: number of packets that were lost

If all packets were lost, the message will contain a subject field
that contains the text:

  Unable to ping host {$host}
