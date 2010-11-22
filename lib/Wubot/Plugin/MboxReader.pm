package Wubot::Plugin::MboxReader;
use Moose;

use Mail::MboxParser;

sub check {
    my ( $self, $config, $cache ) = @_;

    my $results = [];

    my $parseropts = {
        enable_cache    => 0,
        enable_grep     => 1,
        cache_file_name => 'mail/cache-file',
    };

    my $mb = Mail::MboxParser->new( $config->{path},
                                    decode     => 'ALL',
                                    parseropts => $parseropts
                                );

    my $now = time;

    print "Reading: $config->{path}\n";

  MESSAGE:
    while (my $msg = $mb->next_message) {

        my $id = $msg->header->{'message-id'};

        # ignore messages we've already seen
        if ( $cache->{seen}->{ $id } ) {

            #print "Seen: $id\n";

            # update the last seen time
            $cache->{seen}->{ $id } = $now;

            next MESSAGE;
        }
        else {
            # update the last seen time
            $cache->{seen}->{ $id } = $now;
        }

        # new message
        push @{ $results }, { subject  => $msg->header->{subject},
                              username => $msg->header->{from},
                              cc       => $msg->header->{cc},
                              to_user  => $msg->header->{to},
                              date     => $msg->header->{date},
                          };

    }

    for my $id ( keys %{ $cache->{seen} } ) {
        unless ( $cache->{seen}->{ $id } == $now ) {
            #warn "Message removed: $id\n";
            delete $cache->{seen}->{ $id };
        }
    }

    return ( $results, $cache );
}

1;
