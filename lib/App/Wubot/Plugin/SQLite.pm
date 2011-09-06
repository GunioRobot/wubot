package App::Wubot::Plugin::SQLite;
use Moose;

# VERSION

use App::Wubot::Logger;

with 'App::Wubot::Plugin::Roles::Cache';
with 'App::Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    my @react;

    my ( $file ) = glob( $config->{dbfile} );

    my $sqlite =  App::Wubot::SQLite->new( { file => $file } );

    if ( $config->{statements} ) {
        my $return = { coalesce => $self->key };

        for my $statement ( @{ $config->{statements} } ) {
            for my $row ( $sqlite->query( $statement ) ) {

                for my $key ( keys %{ $row } ) {
                    $return->{$key} = $row->{$key};
                }
            }
        }

        push @react, $return;
    }
    elsif ( $config->{statement} ) {
        for my $row ( $sqlite->query( $config->{statement} ) ) {

            if ( $row->{id} ) {
                next if $self->cache_is_seen( $cache, $row->{id} );
                $self->cache_mark_seen( $cache, $row->{id} );
            }

            $row->{coalesce} = $self->key;

            push @react, $row;
        }
    }

    $self->cache_expire( $cache );

    return { cache => $cache, react => \@react };
}

1;

__END__

=head1 NAME

App::Wubot::Plugin::SQLite - monitor results of SQLite queries

=head1

  ~/wubot/config/plugins/SQLite/notifyqueue.yaml

  ---
  delay: 5m
  dbfile: /Users/wu/wubot/sqlite/notify.sql
  statements:
    - SELECT count(*) AS unseen FROM notifications WHERE seen IS NULL


=head1 DESCRIPTION

This plugin executes a sqlite query and sends a message with the
results.

=head1 EXAMPLES

I find it useful to monitor the length of my notification queues.  The
first example monitors the total number of items in the queue that are
unread.

  ~/wubot/config/plugins/SQLite/notifyqueue.yaml

  ---
  delay: 5m
  dbfile: /Users/wu/wubot/sqlite/notify.sql
  statements:
    - SELECT count(*) AS unseen FROM notifications WHERE seen IS NULL

The next example selects the number of items that were added to the
queue in the last 24 hours:

  ~/wubot/config/plugins/SQLite/notify-day.yaml

  ---
  delay: 5m
  dbfile: /Users/wu/wubot/sqlite/notify.sql
  statements:
    - SELECT count(*) AS day FROM notifications WHERE lastupdate > ( select strftime('%s','now','-24 hours') )


=head1 SUBROUTINES/METHODS

=over 8

=item check( $inputs )

The standard monitor check() method.

=back
