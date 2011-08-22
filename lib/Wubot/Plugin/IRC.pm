package Wubot::Plugin::IRC;
use Moose;

# VERSION

use AnyEvent;
use AnyEvent::IRC::Client;
use YAML;

use Wubot::Logger;

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

                                               $channel =~ s|^\#||;

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
                                               $channel =~ s|^\#||;

                                               $self->reactor->( { subject  => "join: $nick: $channel",
                                                                   username => $nick,
                                                                   channel  => $channel,
                                                                   type     => 'join',
                                                               }, $config );
                                           }
                    );

    $self->con->reg_cb( part          => sub { my ( $foo, $nick, $channel, $is_myself, $message ) = @_;

                                               $channel =~ s|^\#||;

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

                                               $channel =~ s|^\#||;

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

__END__


=head1 NAME

Wubot::Plugin::IRC - monitor IRC channels


=head1 SYNOPSIS

  ~/wubot/config/plugins/IRC/mynet.yaml

  ---
  server: remotehost
  port: 6667
  nick: wu
  channel: #somechannel

  ---
  server: 127.0.0.1
  port: 2345
  nick: wu
  channel: #ut3
  password: supersecret


=head1 DESCRIPTION

Monitor IRC.  A message will be sent for the following events:

=over 2

=item connected

  subject: connected

=item disconnected

  subject: disconnected

=item no response to ping

  subject: ping: no response received

A ping will be sent every 60 seconds.  If no ping response is
receieved, the connection will be terminated and automatic reconnect
will begin.

=item publicmsg

  subject: {user}: {channel}: {text}
  text: message text
  channel: channel where message was sent
  username: nick of user who sent the message
  userid: full IRC username
  type: public

=item privatemsg

  subject: {user}: private: {text}
  text: message text
  username: nick of user who sent the private message
  userid: full IRC username
  type: private

=item join

  subject: join: {nick}: {channel}
  username: irc nickname that joined the channel
  channel: channel that was joined
  type: join

=item part

  subject: part: {nick}: {channel}
  username: irc nickname that parted the channel
  channel: channel that was parted
  type: part

=item quit

  subject: quit: {nick}: {message}
  username: irc nickname that parted the channel
  type: quit

=item nick_change

  subject: rename: {oldnick} => {newnick}
  username: original nickname before rename
  type: nick_change

=item channel_topic

  subject: topic: {channel} [[ {topic} ]]
  username: username who set channel topic
  channel: channel where topic was set
  type: topic

=back
