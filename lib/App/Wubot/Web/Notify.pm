package App::Wubot::Web::Notify;
use strict;
use warnings;

# VERSION

use Mojo::Base 'Mojolicious::Controller';

use HTML::Strip;
use  Lingua::Translate;
use Log::Log4perl;
use Text::Wrap;
use URI::Find;

use App::Wubot::Util::Colors;
use App::Wubot::Logger;
use App::Wubot::SQLite;
use App::Wubot::Util::TimeLength;

=head1 NAME

App::Wubot::Web::Notify - web interface for wubot notifications

=head1 CONFIGURATION

   ~/wubot/config/webui.yaml

    ---
    plugins:
      notify:
        '/notify': notify
        '/notify/id/(.id)': item
        '/tags': tags
        '/colors': colors

=head1 DESCRIPTION

The wubot web interface is still under construction!

The notification web interface serves as your notification inbox.  You
can browse through the unread notifications, mark them read, limit the
display to specific plugins or usernames, apply tags, or mark them for
later review.

By default, items in the inbox are grouped and collapsed based on the
'coalesce' field defined in the message.  There are some default
coalesce fields provided by many of the plugins, or you can easily use
rules to alter the defaults.

By convention, wubot messages that are worthy of your attention will
contain a 'subject' field describing the event.  This could be the
subject of an email or rss feed, a tweet, a description of a disk
space problem, etc.  For more information on wubot notifications, see
also L<App::Wubot::Guide::Notifications>.

In order to use the notification web interface, you will first need to
define a rule in the reactor to store the message in the notifications
table.  This can be done with a rule such as:

  - name: notify sql table
    plugin: SQLite
    config:
      file: /Users/wu/wubot/sqlite/notify.sql
      tablename: notifications

The notifications table schema is provided in the wubot distribution,
see the 'schema's section of L<App::Wubot::SQLite> for more
information.

=cut

my $logger = Log::Log4perl::get_logger( __PACKAGE__ );

my $colors = App::Wubot::Util::Colors->new();

my $is_null = "IS NULL";
my $is_not_null = "IS NOT NULL";

my $timelength = App::Wubot::Util::TimeLength->new();

my $notify_file    = join( "/", $ENV{HOME}, "wubot", "sqlite", "notify.sql" );
my $sqlite_notify  = App::Wubot::SQLite->new( { file => $notify_file } );


=head1 SUBROUTINES/METHODS

=over 8

=item notify

Display the notifications web interface

=cut

sub notify {
    my $self = shift;

    my $now = time;

    my $limit = 200;
    if ( $self->param('limit') ) {
        $limit = $self->param('limit');
    }

    my $expand;
    if ( $self->param('expand') ) {
        $expand = 1;
    }

    my $order = 'score DESC, lastupdate DESC, id DESC';
    if ( $self->param( 'order' ) ) {
        $order = $self->param( 'order' );
    }

    my $seen = \$is_null;

    my $old = $self->param( 'old' );
    if ( $old ) {
        $expand = 1;
        $seen = \$is_not_null;
        $order = 'seen DESC';
    }

    my $where = { seen => $seen };

    my $params = $self->req->params->to_hash;
    for my $param ( sort keys %{ $params } ) {
        next unless $params->{$param};
        next unless $param =~ m|^tag_|;

        $param =~ m|^tag_(\d+)|;
        my $id = $1;

        my $cmd = $params->{$param};

        $self->_cmd( $id, $cmd );

    }

    my $seen_id      = $self->param( "seen" );
    if ( $seen_id ) {
        my @seen = split /,/, $seen_id;
        $sqlite_notify->update( 'notifications',
                                { seen => $now   },
                                { id   => \@seen },
                            );

        $self->redirect_to( "/notify" );
    }

    my $key      = $self->param( "key" );
    if ( $key ) {
        $expand = 1;
        $where = { key => $key, seen => $seen };
        if ( ! $old && ! $self->param( 'order' ) ) {
            $order = "lastupdate, id";
        }
    }

    my $username      = $self->param( "username" );
    if ( $username ) {
        $expand = 1;
        $where = { username => $username, seen => $seen };
        if ( ! $old && ! $self->param( 'order' ) ) {
            $order = "lastupdate, id";
        }
    }

    my $plugin      = $self->param( "plugin" );
    if ( $plugin ) {
        $expand = 1;
        $where = { key => { LIKE => "$plugin%" }, seen => $seen };
        if ( ! $old && ! $self->param( 'order' ) ) {
            $order = "lastupdate, id";
        }
    }

    my $mailbox     = $self->param( "mailbox" );
    if ( $mailbox ) {
        $expand = 1;
        if ( $mailbox eq "null" ) {
            $where = { mailbox => undef, seen => $seen };
        }
        else {
            $where = { mailbox => $mailbox, seen => $seen };
        }
        if ( ! $old && ! $self->param( 'order' ) ) {
            $order = "lastupdate, id";
        }
    }

    my $seen_key      = $self->param( "seen_key" );
    if ( $seen_key ) {
        $sqlite_notify->update( 'notifications',
                                { seen => $now },
                                { key  => $seen_key },
                            );

        $self->redirect_to( "/notify" );
    }


    my $tag = $self->param( "tag" );
    if ( $tag ) {
        $expand = 1;
        my @ids;
        for my $row ( $sqlite_notify->select( { tablename => 'tags',
                                                fieldname => 'remoteid',
                                                where     => { tag => $tag },
                                                order     => $order,
                                            } ) ) {

            push @ids, $row->{remoteid};
        }

        $where = { id => \@ids };
    }

    if ( $self->param('collapse') ) {
        $expand = 0;
    }

    my @messages;
    my @ids;
    my $collapse;

  MESSAGE:
    for my $message ( $sqlite_notify->select( { tablename => 'notifications',
                                                where     => $where,
                                                order     => $order,
                                                limit     => $limit,
                                            } ) ) {

        push @ids, $message->{id};

        unless ( $message->{mailbox} ) { $message->{mailbox} = 'null' }

        utf8::decode( $message->{subject} );
        utf8::decode( $message->{subject_text} );
        utf8::decode( $message->{username} );

        my $coalesce = $message->{mailbox};
        if ( ! $expand ) {
            if ( $collapse->{ $coalesce } ) {
                $collapse->{ $coalesce }->{$message->{id}} = 1;
                next MESSAGE;
            }
            else {
                $collapse->{ $coalesce }->{$message->{id}} = 1;
            }
        }

        push @messages, $message;
    }

    for my $message ( @messages ) {
        unless ( $message->{color} ) { $message->{color} = $colors->get_color( 'black' ) }

        if ( $colors->get_color( $message->{color} ) ) {
            $message->{color} = $colors->get_color( $message->{color} );
        }

        my $age = 0;
        if ( $message->{lastupdate} ) {
            $age = $now - $message->{lastupdate};
            $message->{age} = $timelength->get_human_readable( $age );
        }
        $message->{age_color} = $timelength->get_age_color( $age );

        $message->{icon} =~ s|^.*\/||;

        my $coalesce = $message->{mailbox} || $message->{subject};
        $message->{count} = scalar keys %{ $collapse->{ $coalesce } || {} };
        $message->{coalesced} = join( ",", keys %{ $collapse->{ $coalesce } || {} } );

        if ( $message->{key} =~ m|^(.*?)\-(.*)| ) {
            $message->{key1} = $1;
            $message->{key2} = $2;
        }
        else {
            $message->{key1} = $message->{key};
        }
    }

    $self->stash( 'headers', [ qw/cmd num mailbox key1 key2 seen username icon id subject link score age/ ] );

    $self->stash( 'body_data', \@messages );

    $self->stash( 'ids', join( ",", @ids ) );

    my ( $total ) = $sqlite_notify->select( { fields    => 'count(*) as count',
                                          tablename => 'notifications',
                                          where     => { seen => \$is_null },
                                      } );
    $self->stash( 'count', $total->{count} );

    my ( $readme ) = $sqlite_notify->select( { fields    => 'count(*) as count',
                                               tablename => 'tags',
                                               where     => { tag => 'readme' },
                                           } );
    $self->stash( 'readme', $readme->{count} );

    my ( $todo ) = $sqlite_notify->select( { fields    => 'count(*) as count',
                                             tablename => 'tags',
                                             where     => { tag => 'todo' },
                                           } );
    $self->stash( 'todo', $todo->{count} );

    $self->render( template => 'notify' );

};

=item item

Display a single item from the notification queue.

=cut

sub item {
    my $self = shift;

    my $id = $self->stash( 'id' );

    my $cmd = $self->param( 'cmd' );
    if ( $cmd ) {
        $self->_cmd( $id, $cmd );
    }

    my ( $item ) = $sqlite_notify->select( { tablename => 'notifications',
                                             where     => { id => $id },
                                      } );

    my $subject = $self->param( 'subject' );
    if ( ! $cmd && $subject && $subject ne $item->{subject_text} ) {
        $sqlite_notify->update( 'notifications',
                                { subject_text => $subject },
                                { id           => $id  },
                            );
        $self->redirect_to( "/notify/id/$id" );
    }

    my %urls;
    URI::Find->new( sub {
                        my ( $url ) = @_;
                        $urls{$url}++;
                        $url;
                    }
                )->find(\$item->{subject});
    URI::Find->new( sub {
                        my ( $url ) = @_;
                        $urls{$url}++;
                        $url;
                    }
                )->find(\$item->{body});
    for my $url ( keys %urls ) {
        if ( $url =~ m|doubleclick| ) { delete $urls{$url} }
    }
    delete $urls{ $item->{link} };
    $self->stash( urls => [ sort keys %urls ] );

    unless ( $item->{color} ) { $item->{color} = 'black' }
    $item->{color} = $colors->get_color( $item->{color} );

    $item->{icon} =~ s|^.*\/||;

    if ( $item->{body} ) {
        $Text::Wrap::columns = 80;
        my $hs = HTML::Strip->new();
        $item->{body} = $hs->parse( $item->{body} );
        $item->{body} =~ s|\xA0| |g;
        $item->{body} = fill( "", "", $item->{body});
    }

    for my $field ( qw( body subject_text username ) ) {
        utf8::decode( $item->{$field} );
    }

    $self->stash( item => $item );

    my @tags;
    $sqlite_notify->select( { tablename => 'tags',
                              fieldname => 'tag',
                              where     => { remoteid => $item->{id} },
                              order     => 'tag',
                              callback  => sub { my $entry = shift;
                                                 push @tags, $entry->{tag};
                                             },
                          } );
    $self->stash( tags => \@tags );

    $self->render( template => 'item' );
}

sub _cmd {
    my ( $self, $id, $cmd ) = @_;

    $logger->error( "ID:id COMMAND:$cmd" );

    my $now = time;

    for my $tag ( split /\s*,\s*/, $cmd ) {

        if ( $tag eq "r" ) {
            #print "Marking read: $id\n";
            $sqlite_notify->update( 'notifications',
                                    { seen => $now },
                                    { id   => $id  },
                                );

        }
        elsif ( $tag eq "rr" ) {
            my ( $entry ) = $sqlite_notify->select( { tablename => 'notifications',
                                                      fields    => 'subject',
                                                      where     => { id => $id },
                                                  } );
            #print "Marking read: $entry->{subject}\n";
            $sqlite_notify->update( 'notifications',
                                    { seen => $now },
                                    { subject => $entry->{subject} },
                                );

        }
        elsif ( $tag eq "r.*" ) {
            $sqlite_notify->update( 'notifications',
                                    { seen => $now },
                                    {},
                                );
        }
        elsif ( $tag =~ m|^r\.(.*)$| ) {
            $sqlite_notify->update( 'notifications',
                                    { seen => $now },
                                    { subject => { 'LIKE' => "%$1%" } },
                                );
        }
        elsif ( $tag =~ m|^\d+$| ) {
            if ( $tag eq "00" ) { $tag = undef }
            $sqlite_notify->update( 'notifications',
                                    { score => $tag },
                                    { id => $id },
                                );
        }
        elsif ( $colors->get_color( $tag ) ne $tag ) {
            $sqlite_notify->update( 'notifications',
                                    { color => $tag },
                                    { id    => $id  },
                                );
        }
        elsif ( $tag =~ m|^-| ) {
            $tag =~ s|^\-||;
            print "Removing tag $tag on id $id\n";
            $sqlite_notify->delete( 'tags',
                                    { remoteid => $id, tag => $tag, tablename => 'notifications' },
                                );
        }
        elsif ( $tag eq "x" ) {
            print "Removing tag readme from id $id\n";
            $sqlite_notify->delete( 'tags',
                                    { remoteid => $id, tag => 'readme', tablename => 'notifications' },
                                );
            $sqlite_notify->update( 'notifications',
                                    { seen => $now },
                                    { id   => $id  },
                                );
        }
        elsif ( $tag eq "m" ) {
            print "Setting README tag on id $id and marking seen\n";
            $sqlite_notify->insert( 'tags',
                                    { remoteid => $id, tag => 'readme', tablename => 'notifications', lastupdate => time },
                                );
            $sqlite_notify->update( 'notifications',
                                    { seen => $now },
                                    { id   => $id  },
                                );
        }
        elsif ( $tag =~ m|tr (\w+)| ) {
            my $src_lang = $1;
            print "Translating subject from $src_lang\n";
            my ( $entry ) = $sqlite_notify->select( { tablename => 'notifications',
                                                      fields    => 'subject',
                                                      where     => { id => $id },
                                                  } );

            my $xl8r = Lingua::Translate->new(src => $src_lang,
                                              dest => "en" )
                or die "No translation server available";

            my $english = $xl8r->translate($entry->{subject});
            chomp $english;

            if ( $english ) {
                print "TRANSLATED: $english\n";

                $sqlite_notify->update( 'notifications',
                                        { subject_text => $english   },
                                        { id   => $id },
                                    );
            }

        }
        else {
            print "Setting tag $tag on id $id\n";
            $sqlite_notify->insert( 'tags',
                                    { remoteid => $id, tag => $tag, tablename => 'notifications', lastupdate => time },
                                );
        }
    }
}

=item tags

Display the tags web interface.

=cut

sub tags {
    my $self = shift;

    my @tags;

    my $now = time;

    for my $tag ( $sqlite_notify->select( { tablename => 'tags',
                                            fields    => 'count(*) as count, tag, lastupdate',
                                            group     => 'tag',
                                            order     => 'lastupdate DESC, id DESC',
                                        } ) ) {

        my $age = $now - $tag->{lastupdate};

        $tag->{age} = $timelength->get_human_readable( $age );
        $tag->{age_color} = $timelength->get_age_color( $age );

        push @tags, $tag;
    }

    $self->stash( 'tags', \@tags );

    $self->render( template => 'tags' );

};

=item colors

Display the range of the age colors used in the timeline.

=cut

sub colors {
    my $self = shift;

    my @times;

    push @times, map { $_ * 60 } ( 0 .. 59 );

    push @times, map { $_ * 60 * 24 + 60*60 } ( 0 .. 59 );
    push @times, map { $_ * 60 * 24 * 7 + 60*60*24 } ( 0 .. 59 );
    push @times, map { $_ * 60 * 24 * 30 + 60*60*24*7  } ( 0 .. 59 );
    push @times, map { $_ * 60 * 24 * 365 * 2 + 60*60*24*30 } ( 0 .. 59 );

    my @results;

    for my $age ( @times ) {

        my $time = $timelength->get_human_readable( $age );
        my $color = $timelength->get_age_color( $age );

        push @results, { time => $time, color => $color };
    }

    $self->render( template => 'colors', results => \@results );

}

1;

__END__


=back
