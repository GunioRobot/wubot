package Wubot::Reactor::MessagePoster;
use Moose;

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
        warn "MessageQueuePoster: error sending message\n";
        return;
    }

    return $message;
}

1;

