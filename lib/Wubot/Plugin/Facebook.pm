package Wubot::Plugin::Facebook;
use Moose;

# VERSION

use HTML::TokeParser::Simple;

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

    $self->logger->debug( "Fetching content from: $config->{url}" );

    my $content;
    eval {                      # try
        $content = $self->fetcher->fetch( $config->{url}, $config );
        1;
    } or do {                   # catch
        my $error = $@;
        my $subject = "Request failure: $error";
        $self->logger->error( $self->key . ": $subject" );
        return { react => { subject => $subject } };
    };

    $content =~ s|\\u003c|\<|g;
    $content =~ s|\\u200e||g;
    $content =~ s|\\||g;


    my @messages;

    while ( $content =~ m|(<script.*?</script>)|sg ) {

        my $script = $1;

        next unless $script =~ m|pagelet_sub_stream_|;

        $script =~ m|^.*?(<div.*div>)|;

        my $div = $1;

        #print "DIV: $div\n";

        # Parse HTML and pull entires
        my $p = HTML::TokeParser::Simple->new( \$div );

        my $username;

        while ( my $token = $p->get_token ) {

            if ( $token->is_tag('div') && $token->as_is =~ m|actorName actorDescription| ) {
                $token = $p->get_token;
                if ( $token->is_tag( 'a' ) || $token->is_tag( 'span' ) ) {
                    $token = $p->get_token;
                }
                $username = $token->as_is;
            } elsif ( $token->as_is =~ m|messageBody| ) {

                my $subject;
                while ( my $token = $p->get_token ) {
                    last if $token->is_end_tag( 'span' );
                    $subject .= " ";
                    next if $token->is_tag( 'br' );
                    next if $token->is_tag( 'a' );
                    next if $token->is_end_tag( 'a' );
                    $subject .= $token->as_is;
                }

                $subject =~ s|\s*\<wbr\/\>\s*||sg;

                $subject = HTML::Entities::decode( $subject );
                $username = HTML::Entities::decode( $username );

                push @messages, { subject  => $subject,
                                  username => $username,
                                  link     => $config->{url},
                              };

            } elsif ( $token->is_tag('div') && $token->as_is =~ m|commentContent UIImageBlock_Content| ) {
                $token = $p->get_token;
                if ( $token->is_tag( 'a' ) || $token->is_tag( 'span' ) ) {
                    $token = $p->get_token;
                }
                $username = HTML::Entities::decode( $token->as_is );
            } elsif ( $token->is_tag('span') && $token->as_is =~ m|data-jsid="text"| ) {

                my $subject;
                while ( my $token = $p->get_token ) {
                    last if $token->is_end_tag( 'span' );
                    $subject .= " ";
                    next if $token->is_tag( 'br' );
                    next if $token->is_tag( 'a' );
                    next if $token->is_end_tag( 'a' );
                    $subject .= $token->as_is;
                }

                $subject =~ s|\s*\<wbr\/\>\s*||sg;

                $subject = HTML::Entities::decode( $subject );
                $username = HTML::Entities::decode( $username );

                push @messages, { subject  => $subject,
                                  title    => $subject,
                                  body     => $subject,
                                  username => $username,
                                  link     => $config->{url},
                              };
            }
        }

        my @return;

      MESSAGE:
        for my $message ( @messages ) {

            if ( $self->cache_is_seen( $cache, $message->{subject} ) ) {
                $self->logger->trace( "Already seen: ", $message->{subject} );

                # touch cache time on this subject
                $self->cache_mark_seen( $cache, $message->{subject} );

                next MESSAGE;
            }

            # keep track of this item so we don't alert for it again
            $self->cache_mark_seen( $cache, $message->{subject} );

            push @return, $message;
        }

        $self->cache_expire( $cache );

        return { cache => $cache, react => \@return };
    }
}
1;

__END__


=head1 NAME

Wubot::Plugin::Facebook - scrape facebook wall

