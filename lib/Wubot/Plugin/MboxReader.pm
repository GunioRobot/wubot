package Wubot::Plugin::MboxReader;
use Moose;

use Mail::MboxParser;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';
with 'Wubot::Plugin::Roles::Reactor';

sub check {
    my ( $self, $config ) = @_;

    my $parseropts = {
        enable_cache    => 0,
        enable_grep     => 1,
        cache_file_name => 'mail/cache-file',
    };

    my $key = $self->key;

    my $mb = Mail::MboxParser->new( $config->{path},
                                    decode     => 'ALL',
                                    parseropts => $parseropts
                                );

    my $now = time;

    my $new_count = 0;
  MESSAGE:
    while (my $msg = $mb->next_message) {

        my $id = $msg->header->{'message-id'};

        # ignore messages we've already seen
        if ( $self->cache_is_seen( $id ) ) {

            #print "Seen: $id\n";

            # update the last seen time
            $self->cache_mark_seen( $id );

            next MESSAGE;
        }

        # cache this new id
        $self->cache_mark_seen( $id );

        $new_count++;

        # new message
        $self->react( { subject  => $msg->header->{subject},
                        username => $msg->header->{from},
                        cc       => $msg->header->{cc},
                        to_user  => $msg->header->{to},
                        date     => $msg->header->{date},
                    } );

    }
    if ( $new_count ) {
        $self->logger->info( "Found new emails: $key: $new_count" );
    }

    # expire old subjects from the cache
    $self->cache_expire();

    return 1;
}

1;
