package Wubot::Plugin::OsxVolume;
use Moose;

# VERSION

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    my $settings;

    for my $setting ( split /\, /, `osascript -e 'get volume settings'` ) {

        $setting =~ m|^(.*)\:(.*)$|;

        $settings->{ $1 } = $2;
    }

    if ( $config->{alert_muted} && $settings->{'output muted'} eq "true" ) {
        return { react => { subject => 'volume muted' } };
    }

    if ( $settings->{'output volume'} < $config->{min_volume} ) {
        return { react => { subject => "low volume: $settings->{'output volume'}" } };
    }

    return;
}

1;
