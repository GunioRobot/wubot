package Wubot::Reactor;
use Moose;

use Digest::MD5 qw( md5_hex );
use Log::Log4perl;
use Sys::Hostname qw();

use Wubot::LocalMessageStore;

has 'directory' => ( is => 'ro',
                     isa => 'Str',
                     default => sub {
                         my $dir = "$ENV{HOME}/wubot/messages";
                         return $dir;
                     },
                 );

has 'mailbox'   => ( is      => 'ro',
                     isa     => 'Wubot::LocalMessageStore',
                     lazy    => 1,
                     default => sub {
                         return Wubot::LocalMessageStore->new();
                     },
                 );

has 'hostname' => ( is => 'ro',
                    isa => 'Str',
                    lazy => 1,
                    default => sub {
                        my $hostname = Sys::Hostname::hostname();
                        $hostname =~ s|\..*$||;
                        return $hostname;
                    },
                );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'count'    => ( is => 'rw',
                    isa => 'Num',
                    default => 1,
                );


sub react {
    my ( $self, $message ) = @_;

    return unless $message;

    $message->{checksum}   = $self->checksum( $message );

    unless ( $message->{lastupdate} ) {
        $message->{lastupdate} = time;
    }

    $message->{hostname}  = $self->hostname;

    my $count = $self->count;
    $message->{reactor_id} = $count;
    $self->count( $count+1 );

    $self->mailbox->store( $message, $self->directory );
}


sub checksum {
    my ( $self, $message ) = @_;

    my $text = YAML::Dump $message;

    utf8::encode( $text );

    return md5_hex( $text );
}


1;
