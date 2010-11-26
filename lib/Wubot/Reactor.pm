package Wubot::Reactor;
use Moose;

use Log::Log4perl;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'message_directory' => ( is => 'ro',
                             isa => 'Str',
                             default => sub {
                                 my $dir = "$ENV{HOME}/wubot/messages";
                                 return $dir;
                             },
                         );

sub react {
    my ( $self, $message ) = @_;

    unless ( $message->{checksum} ) {
        $self->logger->warn( "ERROR: Message sent without checksum: ", YAML::Dump( $message ) );
        next MESSAGE;
    }

    my $message_file = join( "/", $self->message_directory, "$message->{checksum}.yaml" );

    $self->logger->debug( "\twriting: $message_file" );
    YAML::DumpFile( $message_file, $message );

    print YAML::Dump { file => $message_file, message => $message };

}

1;
