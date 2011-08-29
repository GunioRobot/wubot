package Wubot::Plugin::RSS;
use Moose;

# VERSION

use XML::Feed;

use Wubot::Logger;
use Wubot::Util::WebFetcher;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

has 'fetcher' => ( is  => 'ro',
                   isa => 'Wubot::Util::WebFetcher',
                   lazy => 1,
                   default => sub {
                       return Wubot::Util::WebFetcher->new();
                   },
               );

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

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
                        coalesce   => $self->key,
                    };

        push @react, $article;
    }

    $self->cache_expire( $cache );

    my $output = $self->key . ": check successful: $newcount new items in feed ($count total)";
    $self->logger->debug( $output );

    return { cache => $cache, react => \@react };
}

1;


__END__


=head1 NAME

Wubot::Plugin::RSS - monitor an RSS feed


=head1 SYNOPSIS

  ~/wubot/config/plugins/RSS/slashdot.yaml

  ---
  tags: news
  url: http://rss.slashdot.org/Slashdot/slashdot
  delay: 30m

  ~/wubot/config/plugins/RSS/my-feed-name.yaml

  ---
  url: http://www.xyz.com/rss
  delay: 1h
  user: dude
  pass: lebowski
  proxy: socks://localhost:2080


=head1 DESCRIPTION

Monitors an RSS/Atom feed (anything that can be parsed with
L<XML::Feed>).  Sends a message any time a new article shows up in the
feed.  The message will contain the following fields:

  title: the article title
  subject: the article title, used for notifications
  link: the link
  body: article body

=head1 ERRORS

If an error occurs requesting the data, a reactor message will be sent
containing the error in the subject, e.g.:

  subject: Request failure: 404 Not Found


If the RSS feed cannot be parsed by XML::Feed, a message will be sent
containing the XML::Feed->errstr, e.g.:

  subject: Failure parsing XML Feed: $error text

If the feed contains no articles, the message will contain the text:

  subject: RSS-myfeed: No items in feed

=head1 CACHE

The RSS monitor uses the global cache mechanism, so each time the
check runs, it will update a file such as:

  ~/wubot/cache/RSS-myfeed.yaml

The monitor caches all subject in the feed.  When a new (previously
unseen) subject shows up on the feed, the message will be sent, and
the cache will be updated.  Removing the cache file will cause all
items in the feed to be sent again.

=head1 SEE ALSO

This plugin uses L<Wubot::Util::WebFetcher>.


=head1 SUBROUTINES/METHODS

=over 8

=item check( $inputs )

The standard monitor check() method.

=back
