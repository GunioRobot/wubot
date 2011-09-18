package App::Wubot::Reactor::UrlLengthen;
use Moose;

# VERSION

use LWP::UserAgent;
use URI::Find;
use WWW::LongURL;

use App::Wubot::Logger;

=head1 NAME

App::Wubot::Reactor::UrlLengthen - lengthen URLs using WWW::LongURL

=head1 SYNOPSIS

  - name: length URLs
    condition: subject matches http
    plugin: UrlLengthen
    config:
      field: subject


=head1 DESCRIPTION

Lengthen shortened URLs using L<WWW::LongURL>.

URLs are found in the specified fields using L<URI::Find>.

=cut

has 'ua'      => ( is => 'ro',
                   isa => 'LWP::UserAgent',
                   lazy => 1,
                   default => sub {
                       my $ua = LWP::UserAgent->new();
                       $ua->timeout(10);
                       $ua->max_redirect( 0 );
                       return $ua;
                   },
               );

has 'longurl' => ( is => 'ro',
                   isa => 'WWW::LongURL',
                   lazy => 1,
                   default => sub {
                       WWW::LongURL->new();
                   },
               );

has 'urlfinder'  => ( is => 'ro',
                      isa => 'URI::Find',
                      lazy => 1,
                      default => sub {
                          URI::Find->new();
                      },
                  );

has 'cache'   => ( is => 'ro',
                   isa => 'HashRef',
                   lazy => 1,
                   default => sub { {} },
               );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=cut

sub react {
    my ( $self, $message, $config ) = @_;

    my $field    = $config->{field};

    my $value = $message->{ $field };

    return unless $field && $value;

    $self->logger->debug( "Checking for url: $value" );

    my %urls;

    URI::Find->new( sub {
                        my ( $url ) = @_;
                        $urls{$url} = $self->expand( $url );
                    }
                )->find(\$value);

    for my $url ( keys %urls ) {
        my $lengthened_url = $urls{$url};

        next unless $url && $lengthened_url;

        next if $url eq $lengthened_url;

        $message->{$field} =~ s|$url|$lengthened_url|g;
    }

    return $message;
}

=item expand( $url )

Given a URL, attempt to expand it.

=cut

sub expand {
    my ( $self, $url ) = @_;

    if ( $self->cache->{ $url } ) {
        $self->logger->debug( "Cached url: $url" );
        return $self->cache->{ $url };
    }

    $self->logger->debug( "Lookup url: $url" );
    my $expanded_url = $self->longurl->expand($url);

    unless ( $expanded_url ) {
        return $url;
    }

    $self->logger->debug( "Expanded: $url => $expanded_url" );

    if ( $expanded_url =~ m|plt\.me| ) {
        $expanded_url = $self->expand_pltme( $expanded_url );
    }

    if ( $expanded_url =~ m|plusist\.com| ) {
        $expanded_url = $self->expand_plusist( $expanded_url );
    }

    $self->cache->{ $url } = $expanded_url;

    return $expanded_url;
}

=item expand_pltme( $url )

Expand plt.me URLs.  I have been seeing a lot of these lately and they
do not get expanded by WWW::LongURL yet.

=cut

sub expand_pltme {
    my ( $self, $url ) = @_;

    $self->logger->debug( "Getting content of $url" );
    my $response = $self->ua->get( $url );

    my $content = $response->decoded_content;

    return $url unless $content =~ m|window.location\s\=\s\"(.*)\"|;

    $url = $1;
    $self->logger->debug( "Expanded url: $url" );

    my $head = $self->ua->head($url);

    return $head->{_headers}->{location};
}

=item expand_plusist( $url )

Retrieve the target URL from plusist URLs.

These are especially annoying since the URL in the browser shows up as
the plusist URL, and the actual content is rendered in a frame.

THis method gets the content of the plusist wrapper page and then
parses the link from the link-frame.

=cut

sub expand_plusist {
    my ( $self, $url ) = @_;

    $self->logger->debug( "Getting content of $url" );
    my $response = $self->ua->get( $url );

    my $content = $response->decoded_content;

    return $url unless $content =~ m|iframe id=\"link-frame\" src=\"(.*?)\"|;

    $url = $1;
    $self->logger->debug( "Expanded url: $url" );

    return $url;
}



__PACKAGE__->meta->make_immutable;

1;

__END__


=back
