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
    my ( $self, $inputs ) = @_;

    my $cache = $inputs->{cache};

    # schedule next retry immediately, then go back to waiting on the
    # normal delay count
    $cache->{next_retry} = time;

    return { cache => $cache };
}

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

    my $now = time;
    if ( $cache->{next_retry} && $cache->{next_retry} > $now ) {
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

    my @react;

    unless ( $content =~ m|\!OK\!| ) {
        $cache->{retry_failures}++;
        $cache->{next_retry} = $self->get_next_retry_utime( $cache->{retry_failures} );
        my $subject = "$self->{cache}->{retry_failures} error(s) sending message, retry after " . scalar localtime( $cache->{next_retry} );

        push @react, { subject => $subject };

        warn "MessageQueuePoster: $subject\n";
        return { cache => $cache };
    }

    $cache->{retry_failures} = 0;
    $cache->{next_retry} = undef;
    $cache->{last_ok} = $now;

    return { cache => $cache, react => \@react };
}

1;

