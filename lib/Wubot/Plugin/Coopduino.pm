package Wubot::Plugin::Coopduino;
use Moose;

# VERSION

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );



with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub validate_config {
    my ( $self, $config ) = @_;

    return 1;
}

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    my @react;

    my $file = $config->{file};

    my $line = `tail -1 $file`;

    $line =~ s|\s*$||;

    my ( $datestamp, $utime, $key, $field, $value ) = split /\s*\,\s*/, $line;

    $field = lc( $field );
    $value =~ s|\s.*$||;

    $self->logger->info( "coopduino: $datestamp => $key: $field = $value" );

    return unless $value;

    return { react => { $field => $value, lastupdate => $utime } };

}

1;
