package Wubot::Plugin::DiskSpace;
use Moose;

# VERSION

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub validate_config {
    my ( $self, $config ) = @_;

    my @required_params = qw( command critical_percent warning_percent );

    for my $param ( @required_params ) {
        unless ( $config->{$param} ) {
            die "ERROR: required config param $param not defined for: ", $self->key, "\n";
        }
    }

    return 1;
}

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    my @react;

  LINE:
    for my $line ( split /\n/, `$config->{command} 2>/dev/null` ) {

        # skip header line
        next if $line =~ m|^Filesystem\s+|;
        next if $line =~ m|Permission denied|;

        next unless $line =~ m|\s(\d+)\%\s*(.*)$|;
        my ( $percent, $mount ) = ( $1, $2, $3 );

        # skip-able filesystems
        for my $skip ( keys %{ $config->{skip} } ) {
            next LINE if $mount =~ m|$skip|;
        }

        # only trigger a reaction when the percent changes
        next if $cache->{ $mount } && $cache->{ $mount } == $percent;

        # update the cache
        $cache->{ $mount } = $percent;

        my $subject = "";
        my $status = "ok";
        if ( $percent > $config->{critical_percent} ) {
            $subject = "critical: disk use on $mount is $percent";
            $status = 'critical';
        } elsif ( $percent > $config->{warning_percent} ) {
            $subject = "warning: disk use on $mount is $percent";
            $status = 'warning';
        }

        push @react, { filesystem => $mount,
                       percent    => $percent,
                       status     => $status,
                       subject    => $subject,
                   };

    }

    return { cache => $cache, react => \@react };
}

1;
