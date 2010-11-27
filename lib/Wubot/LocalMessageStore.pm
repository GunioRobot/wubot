package Wubot::LocalMessageStore;
use Moose;

# todo
#
# - warn if queue length above a certain size


use Log::Log4perl;
use Maildir::Lite;
use MIME::Entity;
use MIME::Parser;
use YAML;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'id_cache' => ( is => 'ro',
                    isa => 'HashRef',
                    default => sub { {} },
                );


sub store {
    my ( $self, $message, $directory ) = @_;

    unless ( $message->{checksum} ) {
        $self->logger->warn( "ERROR: Message sent without checksum: ", YAML::Dump( $message ) );
        next MESSAGE;
    }

    my $maildir = Maildir::Lite->new( dir => $directory );

    my ($fh,$stat0)=$maildir->creat_message();

    die "creat_message failed" if $stat0;

    my $message_text = YAML::Dump $message;
    utf8::encode( $message_text );

    my $subject = join( ": ", $message->{key}, $message->{subject} || $message->{checksum} );

    my $date = localtime( $message->{lastupdate}||time );

    my $msg = MIME::Entity->build(
        Type        => 'text/plain',
        Date        => $date,
        From        => $message->{username} || 'wubot',
        To          => $message->{to_user}  || 'wubot',
        Subject     => $subject,
        Data        => $message_text,
    );

    $msg->print($fh);

    my $filename = $maildir->{__message_fh}->{fileno $fh}->{filename};
    system( "touch", "--date", $date, "$directory/tmp/$filename" );

    die "delivery failed!\n" if $maildir->deliver_message($fh);

    return 1;
}

sub get {
    my ( $self, $directory ) = @_;

    my $maildir = Maildir::Lite->new( dir => $directory );

    #$maildir->sort('asc');
    $maildir->sort( sub { $self->sort( @_ ) } ); # sort based on user defined function

    $maildir->force_readdir();

    my $parser = new MIME::Parser;
    $parser->output_under("/tmp");

    my ($fh, $status) = $maildir->get_next_message( 'new' );
    return if $status;

    my $content = do { local $/; <$fh> };

    $content =~ s|^.*?\n(?=\-\-\-\n)||s;

    my $message = YAML::Load $content;

    # delete our cached reactor id for this file to prevent a memory leak
    my $file = $maildir->{__message_fh}->{fileno $fh}->{filename};
    delete $self->id_cache->{ $file };

    if ( $maildir->act( $fh, 'S' ) ) { warn( "act failed!\n" ); }

    return $message;
}


sub sort {
    my ( $self, $path, @messages)=@_;

    my %files;
    my @newmessages;
    my %seen;

    foreach my $file (@messages) {

        my $mtime = (stat( "$path/$file" ))[9];

        unless ( $mtime ) {
            die "ERROR: can't stat file: $path/$file";
        }

        $files{$file}->{primary} = $mtime;

        $seen{$mtime}->{$file} = 1;
    }

    my %dupes;
    for my $mtime ( keys %seen ) {
        if ( scalar keys %{ $seen{$mtime} } > 1 ) {
            $dupes{$mtime} = 1;
        }
    }

    # simple sort if there are no duplicated timestamps
    unless ( keys %dupes ) {
        @newmessages= sort { $files{$a}->{primary} <=> $files{$b}->{primary} } keys %files;
    }

    $self->logger->debug( "slower sort due to multiple messages with duplicate timestamps" );

    for my $mtime ( keys %dupes ) {

        for my $file ( keys %{ $seen{$mtime} } ) {

            my $id;

            if ( $self->id_cache->{ $file } ) {
                $id = $self->id_cache->{ $file };
            }
            else {
                open( my $f,"<", "$path/$file" );
                while( my $line=<$f> ) {
                    if ( $line =~ m/^reactor_id\:\s(\d+)/ ) {
                        $id = $1;
                        last;
                    }
                }
                close( $f );
            }

            $files{ $file }->{secondary} = $id;
        }
    }

    @newmessages= sort { $files{$a}->{primary}   <=> $files{$b}->{primary}   ||
                         $files{$a}->{secondary} <=> $files{$b}->{secondary}
                     } keys %files;


    return @newmessages;
}


1;
