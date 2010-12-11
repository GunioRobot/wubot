package Wubot::Reactor::Maildir;
use Moose;

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

    my $mailbox;
    if ( $message->{mailbox} ) {
        $mailbox = $message->{mailbox};
    }
    elsif ( $config->{mailbox} ) {
        $mailbox = $config->{mailbox};
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

    my $body = $message->{body_text} || $message->{body} || "";
    my $body_text = "FEED:    $key\nSUBJECT: $message->{subject}\n\n$body\n";

    my %message_data = (
        Type        => 'text/plain',
        Date        => $date,
        From        => $message->{username}     || $message->{key},
        To          => $message->{to_user}      || 'wubot',
        Subject     => $message->{subject_text} || $message->{subject},
        Data        => $body,
    );

    my $msg = MIME::Entity->build( %message_data );

    if ( $message->{body_text} && $message->{body} ne $message->{body_text} ) {

        $msg->attach( Data => $message->{body},
                      Type => 'text/html',
                  );

    }

    $msg->print($fh);

  TRY:
    do {
        eval {                          # try
            $maildir->deliver_message($fh);
            1;
        } or do {                       # catch
            my $error = $@;

            if ( $error =~ m|already exists| ) {
                redo TRY;
            }

            die "Delivery failed: $error";
        };
    };

    return $message;
}

1;
