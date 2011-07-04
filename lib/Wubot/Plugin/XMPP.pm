package Wubot::Plugin::XMPP;
use Moose;

# VERSION

use AnyEvent::XMPP::Client;
use Encode;
use Log::Log4perl;
use MIME::Base64;
use YAML;

use Wubot::LocalMessageStore;

has 'mailbox'   => ( is      => 'ro',
                     isa     => 'Wubot::LocalMessageStore',
                     lazy    => 1,
                     default => sub {
                         return Wubot::LocalMessageStore->new();
                     },
                 );

has 'reactor'  => ( is => 'ro',
                    isa => 'CodeRef',
                    required => 1,
                );


has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

    # if connected, see if there are any outgoing messages in the queue
    if ( $self->{cl} ) {

        # nothing to do unless the session is ready
        return {} unless $self->{session_ready};

        # if there's no table to transmit data from, we're done here
        return {} unless $config->{directory};

      MESSAGE:
        for ( 1 .. 10 ) {
            # get message from the queue
            my ( $message, $callback ) = $self->mailbox->get( $config->{directory} );

            last unless $message;

            # convert to text
            my $message_text = MIME::Base64::encode( Encode::encode( "UTF-8", YAML::Dump $message ) );

            # cancel the forward flag when picking up a message
            delete $message->{forward};

            # send the message using YAML
            $self->{cl}->send_message( $message_text => $config->{user}, undef, 'chat' );

            # delete message from the queue
            $callback->();
        }

        return {};
    }

    my $debug = $config->{debug} || 0;

    $self->{cl} = AnyEvent::XMPP::Client->new( debug => $debug );

    $self->{cl}->add_account( $config->{account}, $config->{password}, $config->{host}, $config->{port} );

    $self->{cl}->reg_cb( session_ready => sub {
                             my ($cl, $acc) = @_;
                             $self->{session_ready} = 1;
                             $self->reactor->( { subject => "XMPP: session ready" } );
                         },
                         disconnect => sub {
                             my ($cl, $acc, $h, $p, $reas) = @_;
                             my $details = "";
                             if ( $h && $p ) { $details = "($h:$p)" };
                             $self->logger->error( "XMPP: disconnect $details: $reas" );
                             $self->reactor->( { subject => "XMPP: disconnect $details: $reas", no_post => 1 } );
                             delete $self->{cl};
                             delete $self->{session_ready};
                         },
                         error => sub {
                             my ($cl, $acc, $err) = @_;
                             $self->logger->error( "XMPP: ERROR: " . $err->string );
                             $self->reactor->( { subject => "XMPP: ERROR: " . $err->string } );
                         },
                         message => sub {
                             my ($cl, $acc, $msg) = @_;
                             my $body = $msg->any_body;

                             my $data;

                             eval { # try
                                 $data = YAML::Load( MIME::Base64::decode( Encode::decode( "UTF-8", $body ) ) );
                                 $self->reactor->( $data );
                                 1;
                             } or do { # catch
                                 $self->logger->error( "UNABLE TO DECODE MESSAGE" );
                                 $self->logger->info( $body );
                             };

                             $self->logger->debug( "XMPP: Message received from: " . $msg->from );
                         }
                     );

    $self->{cl}->start;

    return {};
}


1;
