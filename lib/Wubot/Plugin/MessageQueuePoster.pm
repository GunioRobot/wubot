package Wubot::Plugin::MessageQueuePoster;
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


with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';
with 'Wubot::Plugin::Roles::Reactor';
with 'Wubot::Plugin::Roles::RetryDelay';

sub init {
    my ( $self, $config ) = @_;

    # schedule next retry immediately, then go back to waiting on the
    # normal delay count
    $self->cache->{next_retry} = time;

}

sub check {
    my ( $self, $config ) = @_;

    my $now = time;
    if ( $self->cache->{next_retry} && $self->cache->{next_retry} > $now ) {
        return;
    }

    my $message = $self->mailbox->get( $config->{directory} );

    return unless $message;

    $message->{service}   = $message->{key};
    $message->{timestamp} = $message->{lastupdate};

    my $message_text = YAML::Dump $message;

    my $ua      = LWP::UserAgent->new();
    my $request = POST( $config->{url}, [ 'message' => $message_text ] );
    my $content = $ua->request($request)->as_string();

    unless ( $content =~ m|\!OK\!| ) {
        $self->cache->{retry_failures}++;
        $self->cache->{next_retry} = $self->get_next_retry_utime( $self->cache->{retry_failures} );
        my $subject = "$self->{cache}->{retry_failures} error(s) sending message, retry after " . scalar localtime( $self->cache->{next_retry} );
        $self->react( { subject => $subject } );
        warn "MessageQueuePoster: $subject\n";
        return;
    }

    $self->cache->{retry_failures} = 0;
    $self->cache->{next_retry} = undef;
    $self->cache->{last_ok} = $now;

    return 1;
}

1;

