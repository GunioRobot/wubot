package Wubot::Reactor::MessageQueue;
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

    $self->mailbox->store( $message, $config->{directory} );

    return $message;
}

1;

