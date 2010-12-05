package Wubot::Reactor::MessagePoster;
use Moose;

use Log::Log4perl;
use LWP::UserAgent;
use HTTP::Request::Common qw{ POST };
use CGI;
use YAML;

use Wubot::LocalMessageStore;

has 'mailbox'   => ( is      => 'ro',
                     isa     => 'Wubot::LocalMessageStore',
                     lazy    => 1,
                     default => sub {
                         return Wubot::LocalMessageStore->new();
                     },
                 );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );



sub react {
    my ( $self, $message, $config ) = @_;

    # compatibility with App:Wubot
    $message->{service}   = $message->{key};
    $message->{timestamp} = $message->{lastupdate};

    my $message_text = YAML::Dump $message;

    my $ua      = LWP::UserAgent->new();
    my $request = POST( $config->{url}, [ 'message' => $message_text ] );
    my $content = $ua->request($request)->as_string();

    unless ( $content =~ m|\!OK\!| ) {
        $self->logger->error( "MessageQueuePoster: error sending message" );
    }

    return $message;
}

1;

