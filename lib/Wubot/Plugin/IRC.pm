package Wubot::Plugin::IRC;
use Moose;

# VERSION

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
    $self->logger->info( "$key: Setting up new connection" );

    $self->con->reg_cb( registered  => sub { $self->reactor->( { subject => "connected" }, $config );
                                             $self->con->send_srv ("JOIN", $config->{channel} );
                                             $self->con->enable_ping( 60,
                                                                      sub {
                                                                          $self->reactor->( { subject => "ping: no response received" }, $config );
                                                                          $self->con->disconnect;
                                                                          $self->con( AnyEvent::IRC::Client->new() );
                                                                          $self->initialized( 0 );
                                                                      } );
                                         }
                    );

    $self->con->reg_cb( disconnect  => sub { $self->reactor->( { subject => "disconnected" }, $config );
                                             $self->initialized( undef );

                                             # replace connection with a new one
                                             #$self->con( AnyEvent::IRC::Client->new() );
                                         }
                    );

    $self->con->reg_cb( publicmsg     => sub { my ( $foo, $channel, $ircmsg ) = @_;

                                               my $text = $ircmsg->{params}->[1];
                                               my $user = $ircmsg->{prefix};
                                               $user =~ s|\!.*||;

                                               $self->reactor->( { subject  => "$user: $channel: $text",
                                                                   text     => $text,
                                                                   channel  => $channel,
                                                                   message  => $text,
                                                                   username => $user,
                                                                   userid   => $ircmsg->{prefix},
                                                                   type     => 'public',
                                                               }, $config );
                                           }
                    );

    $self->con->reg_cb( privatemsg    => sub { my ( $foo, $nick, $ircmsg ) = @_;

                                               my $text = $ircmsg->{params}->[1];
                                               my $user = $ircmsg->{prefix};
                                               $user =~ s|\!.*||;

                                               $self->reactor->( { subject  => "$user: private: $text",
                                                                   text     => $text,
                                                                   message  => $text,
                                                                   username => $user,
                                                                   userid   => $ircmsg->{prefix},
                                                                   type     => 'private',
                                                               }, $config );
                                           }
                    );

    $self->con->reg_cb( join          => sub { my ( $foo, $nick, $channel, $is_myself ) = @_;
                                               $self->reactor->( { subject  => "join: $nick: $channel",
                                                                   username => $nick,
                                                                   channel  => $channel,
                                                                   type     => 'join',
                                                               }, $config );
                                           }
                    );

    $self->con->reg_cb( part          => sub { my ( $foo, $nick, $channel, $is_myself, $message ) = @_;

                                               my $subject = "part: $nick: $channel";
                                               if ( $message ) { $subject .= ": $message"; }

                                               $self->reactor->( { subject  => $subject,
                                                                   username => $nick,
                                                                   channel  => $channel,
                                                                   type     => 'part',
                                                               }, $config );
                                           }
                    );

    $self->con->reg_cb( quit          => sub { my ( $foo, $nick, $message ) = @_;

                                               my $subject = "quit: $nick";
                                               if ( $message ) { $subject .= ": $message"; }

                                               $self->reactor->( { subject  => $subject,
                                                                   username => $nick,
                                                                   type     => 'quit',
                                                               }, $config );
                                           }
                    );

    $self->con->reg_cb( nick_change   => sub { my ( $foo, $oldnick, $newnick, $is_myself ) = @_;
                                               $self->reactor->( { subject  => "rename: $oldnick=> $newnick",
                                                                   username => $oldnick,
                                                                   type     => 'nick_change',
                                                               }, $config );
                                           }
                    );

    $self->con->reg_cb( channel_topic => sub { my ( $foo, $channel, $topic, $who ) = @_;

                                               my $subject = "topic: $channel [[ $topic ]]";
                                               if ( $who ) { $subject .= " ($who)"; }

                                               $self->reactor->( { subject  => $subject,
                                                                   username => $who,
                                                                   channel  => $channel,
                                                                   type     => 'topic',
                                                               }, $config );
                                           }
                    );

    $self->con->connect ( $config->{server},
                          $config->{port},
                          { nick     => $config->{nick},
                            password => $config->{password},
                        }
                      );

    $self->initialized( 1 );

    return { react => { subject => "Initialized connection $config->{server}:$config->{port} => $config->{nick}" } };
}

sub close {
    my ( $self ) = @_;
    $self->con->disconnect;
}



1;
