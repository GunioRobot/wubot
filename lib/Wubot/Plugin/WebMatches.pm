package Wubot::Plugin::WebMatches;
use Moose;

# VERSION

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

    my @react;

    my $regexp = $config->{regexp};

    $self->logger->debug( "REGEXP: $regexp" );

  MATCH:
    while ( $content =~ m|$regexp|mg ) {

        my $match = $1;

        $self->logger->trace( "MATCH: $match" );

        if ( $self->cache_is_seen( $cache, $match ) ) {
            $self->logger->trace( "Already seen: ", $match );

            # touch cache time on this match
            $self->cache_mark_seen( $cache, $match );

            next MATCH;
        }

        $self->cache_mark_seen( $cache, $match );

        push @react, { match => $match, link => $config->{url} };

    }

    $self->cache_expire( $cache );

    return { react => \@react, cache => $cache };
}

1;
