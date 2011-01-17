package Wubot::Reactor::Voice;
use Moose;

use Log::Log4perl;
use POSIX qw(strftime);
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

has 'queue'   => ( is => 'ro',
                   isa => 'Str',
                   default => sub {
                       return join( "/", $ENV{HOME}, "wubot", "sqlite", "voice" );
                   },
               );

sub react {
    my ( $self, $message, $config ) = @_;

    return $message if $message->{quiet};
    return $message if $message->{quiet_voice};

    my $subject = $message->{subject_text} || $message->{subject};
    return $message unless $subject;

    $subject = join( ": ", $message->{key}, $subject );

    if ( $config->{transform} ) {
        for my $transform ( keys %{ $config->{transform} } ) {
            my $text = $config->{transform}->{$transform};
            $subject =~ s|$transform| $text |ig;
        }
    }

    $self->logger->debug( "Saving voice message to queue: $subject" );
    $self->mailbox->store( { subject => $subject }, $self->queue );

    $message->{react}->{voice} = $subject;

    return $message;
}

sub say {
    my ( $self ) = @_;

    my ( $message, $callback ) = $self->mailbox->get( $self->queue );

    return unless $message;

    my $subject = $message->{subject};

    $self->logger->debug( "SAY: $subject" );

    my $return = system( '/usr/bin/say', $subject ) ? 0 : 1;

    $callback->();

    return $return;
}


1;
