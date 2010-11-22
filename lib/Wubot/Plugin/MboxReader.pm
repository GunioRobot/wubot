package Wubot::Plugin::MboxReader;
use Moose;

use Log::Log4perl;
use Mail::MboxParser;

has 'key'     => ( is => 'ro',
                   isa => 'Str',
                   required => 1,
               );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );



sub check {
    my ( $self, $config, $cache ) = @_;

    my $results = [];

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
        if ( $cache->{seen}->{ $id } ) {

            #print "Seen: $id\n";

            # update the last seen time
            $cache->{seen}->{ $id } = $now;

            next MESSAGE;
        }

        # cache this new id
        $cache->{seen}->{ $id } = $now;

        $new_count++;

        # new message
        push @{ $results }, { subject  => $msg->header->{subject},
                              username => $msg->header->{from},
                              cc       => $msg->header->{cc},
                              to_user  => $msg->header->{to},
                              date     => $msg->header->{date},
                          };

    }
    if ( $new_count ) {
        $self->logger->info( "Found new emails: $key: $new_count" );
    }

    my $delete_count = 0;
    for my $id ( keys %{ $cache->{seen} } ) {
        unless ( $cache->{seen}->{ $id } == $now ) {
            delete $cache->{seen}->{ $id };
            $delete_count++;
        }
    }
    if ( $delete_count ) {
        $self->logger->info( "Email removed from mailbox: $key: $delete_count" );
    }

    return ( $results, $cache );
}

1;
