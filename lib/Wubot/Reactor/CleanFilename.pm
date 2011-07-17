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

    my $filename = $message->{ $config->{filename_field} };

    # anything that isn't a specifically allowed character is replaced
    # with an underscore
    $filename =~ s|[^\w\d\_\-\.]+|_|g;

    # replace multiple underscores with a single underscore
    $filename =~ s|\_+|_|g;

    $message->{ $config->{filename_field} } = $filename;

    return $message;
}

1;
