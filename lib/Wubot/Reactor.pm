package Wubot::Reactor;
use Moose;

use Log::Log4perl;

use Wubot::LocalMessageStore;

has 'directory' => ( is => 'ro',
                     isa => 'Str',
                     default => sub {
                         my $dir = "$ENV{HOME}/wubot/messages";
                         return $dir;
                     },
                 );

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
    my ( $self, $message ) = @_;

    return unless $message;

    return $message;
}


1;
