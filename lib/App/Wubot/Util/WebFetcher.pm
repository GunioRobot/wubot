package App::Wubot::Util::WebFetcher;
use Moose;

# VERSION

use HTTP::Message;
use LWP::UserAgent;

use App::Wubot::Logger;

use App::Wubot::Util::WebFetcher;

=head1 NAME

App::Wubot::Util::WebFetcher - fetch content from the web


=head1 SYNOPSIS

    use App::Wubot::Util::WebFetcher;

    has 'fetcher' => ( is  => 'ro',
                       isa => 'App::Wubot::Util::WebFetcher',
                       lazy => 1,
                       default => sub {
                           return App::Wubot::Util::WebFetcher->new();
                       },
                   );

    my $content;
    eval {                          # try
        $content = $self->fetcher->fetch( $config->{url}, $config );
        1;
    } or do {                       # catch
        my $error = $@;
        my $subject = "Request failure: $error";
        $self->logger->error( $self->key . ": $subject" );
        return { cache => $cache, react => { subject => $subject } };
    };

=head1 DESCRIPTION

Fetch data from a URL using LWP::UserAgent.

This utility class is designed to be used by wubot plugins in the
classes App::Wubot::Plugin and App::Wubot::Reactor.


=head1 SUBROUTINES/METHODS

=over 8

=item $obj->fetch( $url, $config );

Fetches content from the specified URL.

If the fetch attempt fails, then this method will die with the error
message.  Plugins that wish to use this library should wrap the
fetch() method in an eval block (see the example above).

The data fetched will be passed to utf8::encode().

The 'config' may contain the following settings:

=over 4

=item timeout

Number of seconds before the fetch times out.  Defaults to 20 seconds.

=item agent

The user agent string.  Defaults to 'Mozilla/6.0'.

=item user

User id for basic auth.  See also 'pass'

=item pass

Password for basic auth.  See also 'user'.

=item proxy

The proxy URL.

=item decompress

If true, sets the Accept-Encoding using HTTP::message::decodable.

=back

=cut

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
        my $results = $res->status_line || "no error text";
        die "$results\n";
    }

    my $content = $res->decoded_content;

    utf8::encode( $content );

    return $content;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=back
