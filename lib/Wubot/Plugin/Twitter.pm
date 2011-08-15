package Wubot::Plugin::Twitter;
use Moose;

# VERSION

use Net::Twitter::Lite;
use Storable;

use Wubot::Logger;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

has 'datafile' => ( is => 'rw',
                    isa => 'Str',
                    default => sub {
                        return join( "/", $ENV{HOME}, "wubot", ".twitter-auth.dat" );
                    },
                );

has 'twitter'  => ( is => 'rw',
                    isa => 'Net::Twitter::Lite',
                    default => sub {
                        return Net::Twitter::Lite->new(
                            consumer_key        => 'WdRFWMj2sJhR9YIObmlA',
                            consumer_secret     => 'cGpm2cigZks4C0RGS6G9X2jfm6oXc3UiHpCDVnmDhM',
                        );
                    },
                );

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

    my $access_tokens = eval { retrieve($self->datafile) } || [];

    if ( @$access_tokens ) {
        $self->twitter->access_token($access_tokens->[0]);
        $self->twitter->access_token_secret($access_tokens->[1]);
    }
    else {
        my $auth_url = $self->twitter->get_authorization_url;
        print " Authorize this application at: $auth_url\nThen, enter the PIN# provided to contunie: ";

        my $pin = <STDIN>; # wait for input
        chomp $pin;

        # request_access_token stores the tokens in $nt AND returns them
        my @access_tokens = $self->twitter->request_access_token(verifier => $pin);

        # save the access tokens
        store( \@access_tokens, $self->datafile );
    }

    my @react;

  TWEET:
    for my $status ( @{ $self->twitter->friends_timeline({ count => 30 }) } ) {

        if ( $self->cache_is_seen( $cache, $status->{text} ) ) {
            $self->logger->trace( "Already seen: ", $status->{text} );

            # touch cache time on this subject
            $self->cache_mark_seen( $cache, $status->{text} );

            next TWEET;
        }

        $self->cache_mark_seen( $cache, $status->{text} );

        my $subject = join( ": ", $status->{user}->{screen_name}, $status->{text} );

        my $entry = { subject  => $subject,
                      text     => $status->{text},
                      username => lc($status->{user}->{screen_name}),
                      profile_image_url => $status->{user}->{profile_image_url},
                  };

        if ( $status->{text} =~ m|(https?\:\/\/\S+)| ) {
            $entry->{link} = $1;
        }

        push @react, $entry;
    }

    $self->cache_expire( $cache );

    return { cache => $cache, react => \@react };
}





1;
