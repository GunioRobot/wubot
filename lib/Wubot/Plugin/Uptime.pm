package Wubot::Plugin::Uptime;
use Moose;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';
with 'Wubot::Plugin::Roles::Reactor';

sub check {
    my ( $self, $inputs ) = @_;

    my $uptime_output = `uptime`;

    $uptime_output =~ m/load averages?\: ([\d\.]+)\,\s+([\d\.]+),\s+([\d\.]+)/;

    $self->logger->info( "load: $1 => $2 => $3" );

    my $results = { '1min'  => $1,
                    '5min'  => $2,
                    '15min' => $3,
                };

    return { react => $results };
}

1;
