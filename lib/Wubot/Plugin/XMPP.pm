package Wubot::Plugin::XMPP;
use Moose;

use AnyEvent::XMPP::Client;
use Log::Log4perl;
use YAML;

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

    if ( $self->{cl} ) {
        return {};
    }

    my $debug = $config->{debug} || 0;

    $self->{cl} = AnyEvent::XMPP::Client->new( debug => $debug );

    $self->{cl}->add_account( $config->{account}, $config->{password} );

    $self->{cl}->reg_cb( session_ready => sub {
                     my ($cl, $acc) = @_;
                     $self->reactor->( { subject => "XMPP: session ready" } );
                 },
                 disconnect => sub {
                     my ($cl, $acc, $h, $p, $reas) = @_;
                     $self->reactor->( { subject => "XMPP: disconnect ($h:$p): $reas" } );
                     delete $self->{cl};
                 },
                 error => sub {
                     my ($cl, $acc, $err) = @_;
                     $self->reactor->( { subject => "XMPP: ERROR: " . $err->string } );
                 },
                 message => sub {
                     my ($cl, $acc, $msg) = @_;
                     my $body = $msg->any_body;

                     my $data;

                     eval {                          # try
                         $data = YAML::Load( $body );
                         1;
                     } or do {                       # catch
                         $data = { subject => $body };
                     };

                     $self->reactor->( $data );

                     $self->logger->debug( "XMPP: Message received from: " . $msg->from );
                 }
             );

    $self->{cl}->start;

    return {};
}


1;
