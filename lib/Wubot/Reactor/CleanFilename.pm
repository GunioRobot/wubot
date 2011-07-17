package Wubot::Reactor::CleanFilename;
use Moose;

# VERSION

use Log::Log4perl;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub react {
    my ( $self, $message, $config ) = @_;

    unless ( $config->{field} ) {
        $self->logger->error( "ERROR: CleanFilename: field not defined in config", YAML::Dump $config );
        return $message;
    }

    my $filename = $message->{ $config->{field} };

    unless ( $filename ) {
        $self->logger->error( "ERROR: CleanFilename: message field $config->{field} not defined" );
        return $message;
    }

    # anything that isn't a specifically allowed character is replaced
    # with an underscore
    if ( $config->{directory} ) {
        $filename =~ s|[^\w\d\_\-\.\/]+|_|g;
    }
    else {
        $filename =~ s|[^\w\d\_\-\.]+|_|g;
    }

    if ( $config->{lc} ) {
        $filename = lc( $filename );
    }

    # replace multiple underscores with a single underscore
    $filename =~ s|\_+|_|g;

    $message->{ $config->{field} } = $filename;

    return $message;
}

1;
