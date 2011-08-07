package Wubot::Plugin::Outlook;
use Moose;

# VERSION

use Date::Manip;
use Encode;
use HTML::TableExtract;
use Log::Log4perl;
use LWP::UserAgent;
use YAML;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    my @react;

    my $content = $self->get_content( $config->{url}, $config );

    unless ( $content ) {
        $self->logger->error( "Critical: outlook: No content retrieved!" );
        return;
    }

    my $count = scalar $self->get_msgids( $content );

    my $message = { count => $count };

    if ( $count ) {
        $message->{subject} = "$count messages in your inbox";
    }

    push @react, $message;

    return { react => \@react };
}

sub get_msgids {
    my ( $self, $content ) = @_;

    my @msgids;

    $content =~ s{name="chkmsg" value="([^"]+)"}{push @msgids, $1}eg;

    my @return;

    for my $msgid ( @msgids ) {
        $msgid =~ s|\/|%2f|g;
        $msgid =~ s|\+|%2b|g;
        push @return, $msgid;
    }

    return @return;
}

sub get_content {
    my ( $self, $url, $config ) = @_;

    my $ua = new LWP::UserAgent;
    $ua->timeout(15);

    if ( $config->{proxy} ) {
        $ua->proxy(['http'],  $config->{proxy} ); # set proxy
        $ua->proxy(['https'], $config->{proxy} ); # set proxy
    }

    $ua->agent("Mozilla/6.0");  # Or something equally mysterious

    my $req = new HTTP::Request GET => $url;
    $req->authorization_basic( $config->{user}, $config->{pass} );

    my $res = $ua->request($req);

    unless ($res->is_success) {
        $self->logger->warn( "Failure checking outlook web: " . $res->status_line );
        return;
    }

    my $content= $res->content;

    return $content;
}

1;
