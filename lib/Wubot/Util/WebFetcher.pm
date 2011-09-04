package Wubot::Util::WebFetcher;
use Moose;

# VERSION

use HTTP::Message;
use LWP::UserAgent;

use Wubot::Logger;

sub fetch {
    my ( $self, $url, $config ) = @_;

    my $ua = new LWP::UserAgent;

    if ( $config->{timeout} ) {
        $ua->timeout( $config->{timeout} );
    }
    else {
        $ua->timeout(20);
    }

    if ( $config->{agent} ) {
        $ua->agent( $config->{agent} );
    }
    else {
        $ua->agent("Mozilla/6.0");
    }

    if ( $config->{proxy} ) {
        $ua->proxy(['http'],  $config->{proxy} );
        $ua->proxy(['https'], $config->{proxy} );
    }

    my $req;
    if ( $config->{decompress} ) {
        my $can_accept = HTTP::Message::decodable;
        $req = new HTTP::Request GET => $url, [ 'Accept-Encoding' => $can_accept ];
    }
    else {
        $req = new HTTP::Request GET => $url;
    }

    if ( $config->{user} && $config->{pass} ) {
        $req->authorization_basic( $config->{user}, $config->{pass} );
    }

    my $res = $ua->request($req);

    unless ( $res->is_success ) {
        return { react => { 'failure fetching: ' . $res->status_line } };
    }

    my $content = $res->decoded_content;

    utf8::encode( $content );

    return $content;
}

1;
