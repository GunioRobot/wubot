package Wubot::Plugin::Uptime;
use Moose;

# VERSION

use Log::Log4perl;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub validate_config {
    my ( $self, $config ) = @_;

    my @required_params = qw( command warning_load critical_load );

    for my $param ( @required_params ) {
        unless ( $config->{$param} ) {
            die "ERROR: required config param $param not defined for: ", $self->key, "\n";
        }
    }

    return 1;
}


sub check {
    my ( $self, $inputs ) = @_;

    $self->logger->debug( "Check command: $inputs->{config}->{command}" );

    my $uptime_output = `$inputs->{config}->{command}`;
    chomp $uptime_output;

    unless ( $uptime_output =~ m/load averages?\: ([\d\.]+)\,?\s+([\d\.]+),?\s+([\d\.]+)/ ) {
        my $subject = $self->key . ": ERROR: unable to parse uptime output: $uptime_output";
        $self->logger->warn( $subject );
        return { react => { subject => $subject } };
    }

    my ( $load01, $load05, $load15 ) = ( $1, $2, $3 );

    $self->logger->debug( "load: $load01 => $load05 => $load15" );

    my $subject;
    my $status = "ok";
    if ( $load01 > $inputs->{config}->{critical_load} ) {
        $subject = "critical: load over last 1 minute is $load01 ";
        $status = 'critical';
    } elsif ( $load01 > $inputs->{config}->{warning_load} ) {
        $subject = "warning: load over last 1 minute is $load01 ";
        $status = 'warning';
    }

    my $results = { load01  => $load01,
                    load05  => $load05,
                    load15  => $load15,
                    status  => $status,
                };

    if ( $subject ) {
        $results->{subject} = $subject;
    }

    return { react => $results };
}

1;
