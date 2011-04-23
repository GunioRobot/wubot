package Wubot::Plugin::Arp;
use Moose;

# VERSION

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
