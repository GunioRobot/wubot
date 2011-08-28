package Wubot::Plugin::Arp;
use Moose;

# VERSION

use Wubot::Logger;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    my $command = $config->{command} || 'arp -a';

    my @react;

  LINE:
    for my $line ( split /\n/, `$command 2>/dev/null` ) {

        $line =~ m|^(\S+)\s\(([\d\.]+)\)\sat\s(\S+)|;

        my ( $name, $ip, $mac ) = ( $1, $2, $3 );

        $mac = $self->standardize_mac( $mac );

        $self->logger->debug( "LINE: $line" );
        $self->logger->debug( "\tname:$name ip:$ip mac:$mac" );

        next LINE if $cache->{ $mac }->{ $ip }->{ $name };
        $cache->{ $mac }->{ $ip }->{ $name } = 1;

        push @react, { name    => $name,
                       ip      => $ip,
                       mac     => $mac,
                       subject => "New arp table entry: $ip ($name) = $mac",
                   };
    }

    return { cache => $cache, react => \@react };
}

sub standardize_mac {
    my ( $self, $mac ) = @_;

    # add leading 0 to single-digit fields in mac address
    return join( ":", map { length "$_" == 1 ? "0$_" : $_ } split( /:/, $mac ) );

}

1;


__END__


=head1 NAME

Wubot::Plugin::Arp - monitor the arp table for new entries


=head1 SYNOPSIS

  ~/wubot/config/plugins/Arp/myhostname.yaml

  ---
  delay: 60


=head1 DESCRIPTION

Monitor the arp table by parsing the output of 'arp -a'.  Any time a
previously unseen entry shows up in the arp table (using a combination
of the name, ip, and mac address), a message will be sent containing:

  name: the hostname
  ip: the host ip address
  mac: the mac address
  subject: New arp table entry: $ip {$name) = $mac

This can be a great tool for alerting you to new machines showing up
on your private network.

=head1 CACHE

The Arp monitor uses the global cache mechanism, so each time the
check runs, it will update a file such as:

  ~/wubot/cache/Arp-myhostname.yaml

The monitor caches all combinations of name+ip+mac.  When a new
(previously unseen) subject shows up on the feed, the message will be
sent, and the cache will be updated.  Removing the cache file will
cause all arp entries to be sent again.

=head1 SQLite

If you wanted to store all ARP addresses in a sqlite database, you
could use a rule such as this in the reactor:

  - name: Arp
    condition: key matches ^Arp
    plugin: SQLite
    config:
      file: /usr/home/wu/wubot/sqlite/mac_address.sql
      tablename: mac_address

The 'mac_address' schema is distributed in the config/schemas/
directory in the wubot distribution.

