package Wubot::Plugin::IRC;
use Moose;

use AnyEvent;
use AnyEvent::IRC::Client;
use Log::Log4perl;
use YAML;


has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'reactor'  => ( is => 'ro',
                    isa => 'CodeRef',
                    required => 1,
                );

has 'con'  => ( is      => 'rw',
                isa     => 'AnyEvent::IRC::Client',
                lazy    => 1,
                default => sub { return AnyEvent::IRC::Client->new() },
            );

has 'initialized' => ( is      => 'rw',
                       isa     => 'Bool',
                       default => 0,
                   );


with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    return {} if $self->initialized;

    my $config = $inputs->{config};
    my $key    = $self->key;

    $self->con->reg_cb( registered  => sub { $self->reactor->( { subject => "connected" } );
                                             $self->con->send_srv ("JOIN", $config->{channel} );
                                         }
                    );

    $self->con->reg_cb( disconnect  => sub { $self->reactor->( { subject => "disconnected" } );
                                             $self->initialized( undef );
                                         }
                    );

    $self->con->reg_cb( publicmsg     => sub { my ( $foo, $channel, $ircmsg ) = @_;

                                               my $text = $ircmsg->{params}->[1];
                                               my $user = $ircmsg->{prefix};
                                               $user =~ s|\!.*||;

                                               $self->reactor->( { subject  => "public: $channel: $text",
                                                                   text     => $text,
                                                                   channel  => $channel,
                                                                   message  => $text,
                                                                   username => $user,
                                                                   userid   => $ircmsg->{prefix},
                                                                   type     => 'public',
                                                               } );
                                           }
                    );

    $self->con->reg_cb( privatemsg    => sub { my ( $foo, $nick, $ircmsg ) = @_;

                                               my $text = $ircmsg->{params}->[1];
                                               my $user = $ircmsg->{prefix};
                                               $user =~ s|\!.*||;

                                               $self->reactor->( { subject  => "private: $nick: $text",
                                                                   text     => $text,
                                                                   message  => $text,
                                                                   username => $user,
                                                                   userid   => $ircmsg->{prefix},
                                                                   type     => 'private',
                                                               } );
                                           }
                    );

    $self->con->reg_cb( join          => sub { my ( $foo, $nick, $channel, $is_myself ) = @_;
                                               $self->reactor->( { subject  => "join: $nick: $channel",
                                                                   username => $nick,
                                                                   channel  => $channel,
                                                                   type     => 'join',
                                                               } );
                                           }
                    );

    $self->con->reg_cb( part          => sub { my ( $foo, $nick, $channel, $is_myself, $message ) = @_;
                                               $self->reactor->( { subject  => "part: $nick: $channel => $message",
                                                                   username => $nick,
                                                                   channel  => $channel,
                                                                   type     => 'part',
                                                               } );
                                           }
                    );

    $self->con->reg_cb( quit          => sub { my ( $foo, $nick, $message ) = @_;
                                               $self->reactor->( { subject  => "quit: $nick: $message",
                                                                   username => $nick,
                                                                   type     => 'quit',
                                                               } );
                                           }
                    );

    $self->con->reg_cb( nick_change   => sub { my ( $foo, $oldnick, $newnick, $is_myself ) = @_;
                                               $self->reactor->( { subject  => "rename: $oldnick=> $newnick",
                                                                   username => $oldnick,
                                                                   type     => 'nick_change',
                                                               } );
                                           }
                    );

    $self->con->reg_cb( channel_topic => sub { my ( $foo, $channel, $topic, $who ) = @_;

                                               my $subject = "topic: $channel [[ $topic ]]";
                                               if ( $who ) { $subject .= " ($who)"; }

                                               $self->reactor->( { subject  => $subject,
                                                                   username => $who,
                                                                   channel  => $channel,
                                                                   type     => 'topic',
                                                               } );
                                           }
                    );

    $self->con->connect ( $config->{server},
                          $config->{port},
                          { nick     => $config->{nick},
                            password => $config->{password},
                        }
                      );

    $self->initialized( 1 );

    return { react => { subject => "$key: Initialized connection $config->{server}:$config->{port} => $config->{nick}" } };
}

sub close {
    my ( $self ) = @_;
    $self->con->disconnect;
}



1;
