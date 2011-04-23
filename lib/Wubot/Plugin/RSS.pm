package Wubot::Plugin::RSS;
use Moose;

use Encode qw(encode decode);
use LWP::UserAgent;
use XML::Feed;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

    my $ua = new LWP::UserAgent;

    my $timeout = $config->{timeout} || 15;
    $ua->timeout( $timeout );

    $ua->agent("Mozilla/6.0");

     # set proxy
    if ( $config->{proxy} ) {
        $ua->proxy(['http'],  $config->{proxy} );
        $ua->proxy(['https'], $config->{proxy} );
    }

    my $req = new HTTP::Request GET => $config->{url};

    if ( $config->{user} && $config->{pass} ) {
        $req->authorization_basic( $config->{user}, $config->{pass} );
    }

    my $res = $ua->request( $req );

    unless ( $res->is_success ) {
        my $error = $res->status_line || "no error text";
        my $subject = "Request failure: $error";
        $self->logger->error( $self->key . ": $subject" );
        return { cache => $cache, react => { subject => $subject } };
    }

    my $content = $res->content;
    my $feed;
    eval { $feed = XML::Feed->parse( \$content ) };

    unless ( $feed ) {
        my $error = XML::Feed->errstr || "no error text";
        my $subject = "Failure parsing XML Feed: $error";
        $self->logger->error( $self->key . ": $subject" );
        return { cache => $cache, react => { subject => $subject } };
    }

    my @entries = $feed->entries;

    my $count = scalar @entries;
    unless ( $count ) {
        $self->logger->warn( $self->key, ": No items in feed" );
        return { cache => $cache, react => { subject => "No items in feed" } };
    }

    my @react;

    my $now = time;
    my $newcount = 0;

    # walk through the current feed and display items that aren't
    # already in the db.  reverse the order of the entries since
    # newest entry is first and we want them in the original order.
  ARTICLE:
    foreach my $i ( reverse @entries ) {
        my $link = $i->link;

        my $subject = $i->title;

        next ARTICLE unless $subject;

        # if we've already seen this item, move along
        if ( $self->cache_is_seen( $cache, $subject ) ) {
            $self->logger->trace( "Already seen: ", $subject );

            # touch cache time on this subject
            $self->cache_mark_seen( $cache, $subject );

            next ARTICLE;
        }

        $newcount++;

        # keep track of this item so we don't fetch it again
        $self->cache_mark_seen( $cache, $subject );

        my $body = $i->content->body;

        my $article = { title      => $subject,
                        subject    => $subject,
                        link       => $link,
                        body       => $body,
                    };

        push @react, $article;
    }

    $self->cache_expire( $cache );

    my $output = $self->key . ": check successful: $newcount new items in feed ($count total)";
    $self->logger->debug( $output );

    return { cache => $cache, react => \@react };
}



1;
