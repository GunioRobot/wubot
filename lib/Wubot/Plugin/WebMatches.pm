package Wubot::Plugin::WebMatches;
use Moose;

# VERSION

use LWP::UserAgent;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

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

    my $req = new HTTP::Request GET => $config->{url};

    if ( $config->{user} && $config->{pass} ) {
        $req->authorization_basic( $config->{user}, $config->{pass} );
    }

    my $res = $ua->request($req);

    unless ($res->is_success) {
        return { react => { 'failure getting updates: ' . $res->status_line } };
    }

    my $content = $res->content;

    my @react;

    my $regexp = $config->{regexp};

    print "REGEXP: $regexp\n";

  MATCH:
    while ( $content =~ m|$regexp|mg ) {

        my $match = $1;

        print "MATCH: $match\n";

        if ( $self->cache_is_seen( $cache, $match ) ) {
            $self->logger->trace( "Already seen: ", $match );

            # touch cache time on this match
            $self->cache_mark_seen( $cache, $match );

            next MATCH;
        }

        $self->cache_mark_seen( $cache, $match );

        push @react, { match => $match };

    }

    $self->cache_expire( $cache );

    return { react => \@react, cache => $cache };
}

1;
