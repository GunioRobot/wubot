package Wubot::Plugin::Arp;
use Moose;

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

        $self->logger->debug( "LINE: $line" );
        $self->logger->debug( "\tname:$name ip:$ip mac:$mac" );

        next LINE if $cache->{ $mac }->{ $ip }->{ $name };
        $cache->{ $mac }->{ $ip }->{ $name } = 1;

        push @react, { name => $1, ip => $2, mac => $3 };
    }

    return { cache => $cache, react => \@react };
}

1;
