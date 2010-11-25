package Wubot::Plugin::RSS;
use Moose;

use Encode qw(encode decode);
use LWP::UserAgent;
use XML::Feed;

with 'Wubot::Plugin::Roles::Plugin';
with 'Wubot::Plugin::Roles::Reactor';

sub check {
    my ( $self, $config, $cache ) = @_;

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
        $self->logger->error( "Failure getting content: ", $res->status_line || "no error text" );
        return $cache;
    }

    my $content = $res->content;
    my $feed;
    eval { $feed = XML::Feed->parse( \$content ) };

    unless ( $feed ) {
        $self->logger->error( "Failure parsing XML Feed: ", XML::Feed->errstr || "no error text" );
        return $cache;
    }

    my @entries = $feed->entries;

    my $count = scalar @entries;
    unless ( $count ) {
        $self->logger->warn( "No items in feed" );
        return $cache;
    }

    my $newfeed = 0;
    if ( ! $cache->{seen} ) { $newfeed = 1 }

    my $newcount = 0;

    my $now = time;

    # walk through the current feed and display items that aren't
    # already in the db.  reverse the order of the entries since
    # newest entry is first and we want them in the original order.
  ARTICLE:
    foreach my $i ( reverse @entries ) {
        my $link = $i->link;

        my $subject = $i->title;
        $subject = encode( 'UTF-8', $subject );

        next ARTICLE unless $subject;

        # if we've already seen this item, move along
        if ( $cache->{seen}->{$subject} ) {
            $self->logger->debug( "Already seen: ", $subject );
            next ARTICLE;
        }

        $newcount++;

        # keep track of this item so we don't fetch it again
        $cache->{seen}->{$subject} = $now;

        my $body = $i->content->body;

        my $article = { title      => $subject,
                        subject    => $subject,
                        link       => $link,
                        body       => $body,
                    };

        if ( $config->{tag} ) {
            $article->{tag} = $config->{tag};
        }

        if ( $newfeed ) {
            $article->{newfeed} = $newfeed;
        }

        $self->react( $article );
    }

    for my $subject ( keys %{ $cache->{seen} } ) {
        unless ( $cache->{seen}->{ $subject } == $now ) {
            delete $cache->{seen}->{ $subject };
            $self->logger->info( "Removing item from cache: $subject" );
        }
    }

    my $output = "check successful: $newcount new items in feed ($count total)";
    if ( $newfeed ) { $output .= " [first check]" }
    $self->logger->info( $output );

    return $cache;
}



1;
