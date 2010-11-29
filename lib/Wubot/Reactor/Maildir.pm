package Wubot::Reactor::Maildir;
use Moose;

use HTML::Strip;
use Maildir::Lite;
use MIME::Entity;
use POSIX qw(strftime);
use Sys::Hostname qw();
use YAML;


BEGIN {
    # temporarily disable warnings for redefine while we monkey-patch Maildir::Lite
    no warnings 'redefine';

    # Maildir::Lite has a bug where it does not properly handle hostnames with dashes
    *Maildir::Lite::hostname = sub { my $hostname = Sys::Hostname::hostname(); $hostname =~ s|\-||g; return $hostname };

    use warnings 'redefine';
}

sub react {
    my ( $self, $message, $config ) = @_;

    return unless $message->{body};

    my $mailbox;
    if ( $message->{mailbox} ) {
        $mailbox = $message->{mailbox};
    }
    else {
        $mailbox = lc( $message->{plugin} );
        $mailbox =~ s|^.*\:||;
    }

    my $key = $message->{key} || $message->{plugin};

    my $maildir = Maildir::Lite->new( dir => "$config->{path}/$mailbox" );

    my $directory = join( "/", $config->{path}, $mailbox );
    unless ( $directory ) {
        die "ERROR: path to maildir not specified";
    }
    unless ( -d $directory ) {
        system( "mkdir", $directory );
    }

    my ($fh,$stat0)=$maildir->creat_message();

    die "creat_message failed" if $stat0;

    my $time = $message->{lastupdate} || time;
    my $date = strftime( "%a, %d %b %Y %H:%M:%S %z", localtime( $time ) );

    my $subject = $message->{subject};

    my $body = $message->{body};

    my $hs = HTML::Strip->new();
    my $body_text = $hs->parse( $body );
    $hs->eof;

    $body_text = "FEED:    $key\nSUBJECT: $subject\n\n$body_text\n";

    my %message_data = (
        Type        => 'text/plain',
        Date        => $date,
        From        => $message->{username} || $message->{key},
        To          => $message->{to_user}  || 'wubot',
        Subject     => $subject,
        Data        => $body_text,
    );

    my $msg = MIME::Entity->build( %message_data );

    $msg->attach( Data => $message->{body},
                  Type => 'text/html',
              );

    $msg->print($fh);

    die "delivery failed!\n" if $maildir->deliver_message($fh);

    return \%message_data;
}

1;
