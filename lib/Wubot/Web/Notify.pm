package Wubot::Web::Notify;
use strict;
use warnings

use Mojo::Base 'Mojolicious::Controller';

use Wubot::Util::Colors;
use Wubot::Logger;
use Wubot::SQLite;
use Wubot::TimeLength;

my $colors = Wubot::Util::Colors->new();

my $is_null = "IS NULL";
my $is_not_null = "IS NOT NULL";

my $timelength = Wubot::TimeLength->new();

my $notify_file    = join( "/", $ENV{HOME}, "wubot", "sqlite", "notify.sql" );
my $sqlite_notify  = Wubot::SQLite->new( { file => $notify_file } );

sub notify {
    my $self = shift;

    my $now = time;

    my $order = 'lastupdate DESC, id DESC';
    if ( $self->param( 'order' ) ) {
        $order = $self->param( 'order' );
    }

    my $seen = \$is_null;

    my $old = $self->param( 'old' );
    if ( $old ) {
        $seen = \$is_not_null;
        $order = 'seen DESC';
    }

    my $where = { seen => $seen };

    my $params = $self->req->params->to_hash;
    for my $param ( sort keys %{ $params } ) {
        next unless $params->{$param};
        next unless $param =~ m|^tag_|;

        my $tag = $params->{$param};

        $param =~ m|^tag_(\d+)|;
        my $id = $1;

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
        elsif ( $colors->get_color( $tag ) ) {
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
        else {
            print "Setting tag $tag on id $id\n";
            $sqlite_notify->insert( 'tags',
                                    { remoteid => $id, tag => $tag, tablename => 'notifications', lastupdate => time },
                                );
        }
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
        $where = { key => $key, seen => $seen };
        if ( ! $old && ! $self->param( 'order' ) ) {
            $order = "lastupdate, id";
        }
    }

    my $username      = $self->param( "username" );
    if ( $username ) {
        $where = { username => $username, seen => $seen };
        if ( ! $old && ! $self->param( 'order' ) ) {
            $order = "lastupdate, id";
        }
    }

    my $plugin      = $self->param( "plugin" );
    if ( $plugin ) {
        $where = { key => { LIKE => "$plugin%" }, seen => $seen };
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

    my @messages;
    my @ids;
    my $collapse;

  MESSAGE:
    for my $message ( $sqlite_notify->select( { tablename => 'notifications',
                                                where     => $where,
                                                order     => $order,
                                                limit     => 100,
                                            } ) ) {

        push @ids, $message->{id};

        utf8::decode( $message->{subject} );

        if ( ! $message->{link} && $message->{subject} =~ m|(https?\:\/\/\S+)| ) {
            $message->{link} = $1;
        }

        my $coalesce = $message->{coalesce} || $message->{subject};
        unless ( $key || $plugin || $username || $old ) {
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

        my $coalesce = $message->{coalesce} || $message->{subject};
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

    $self->stash( 'headers', [qw/cmd key1 key2 seen count username icon subject link age/ ] );

    $self->stash( 'body_data', \@messages );

    $self->stash( 'ids', join( ",", @ids ) );

    my ( $total ) = $sqlite_notify->select( { fields    => 'count(*) as count',
                                          tablename => 'notifications',
                                          where     => { seen => \$is_null },
                                      } );
    $self->stash( 'count', $total->{count} );

    $self->render( template => 'notify' );

};

sub tags {
    my $self = shift;

    my @tags;

    my $now = time;

    for my $tag ( $sqlite_notify->select( { tablename => 'tags',
                                            fields    => 'distinct tag, lastupdate',
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


1;

