package Wubot::LocalMessageStore;
use Moose;

# VERSION

# todo - warn if queue length above a certain size

use Digest::MD5 qw( md5_hex );
use File::Path;
use Log::Log4perl;
use POSIX qw(strftime);
use Sys::Hostname qw();
use YAML::XS;

use Wubot::Reactor;
use Wubot::SQLite;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
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

has 'sqlite'  => ( is => 'ro',
                   isa => 'HashRef',
                   default => sub { {} },
               );

has 'reactor' => ( is => 'ro',
                   default => undef,
               );


sub initialize_db {
    my ( $self, $directory ) = @_;

    unless ( -d $directory ) {
        mkpath( $directory );
    }

    my $dbfile = "$directory/queue.sqlite";

    $self->sqlite->{ $dbfile } = Wubot::SQLite->new( { file => $dbfile } );

    $self->delete_seen( $directory, 24*60*60 );

    my ( $seen, $unseen, $total ) = $self->get_counts( $directory );

    if ( $total ) {

        if ( $total > 100000 ) {
            $self->logger->fatal( "queue length: $total ($seen/$unseen): $dbfile" );
        }
        elsif ( $total > 30000 ) {
            $self->logger->error( "queue length: $total ($seen/$unseen): $dbfile" );
        }
        else {
            $self->logger->warn( "queue length: $total ($seen/$unseen): $dbfile" );
        }

        # if ( $self->reactor ) {
        #     $self->reactor->react( { subject => "seen queue length: $length",
        #                              file    => $dbfile,
        #                              length  => $length,
        #                          } );
        # }
    }

}

sub store {
    my ( $self, $message, $directory ) = @_;

    unless ( -d $directory ) {
        mkpath( $directory );
    }

    my $dbfile = "$directory/queue.sqlite";

    # if we don't have a sqlite object for this file, create one now
    unless ( $self->sqlite->{ $dbfile } ) {
        $self->initialize_db( $directory );
    }

    unless ( $message->{checksum} ) {
        $message->{checksum}   = $self->checksum( $message );
    }

    unless ( $message->{lastupdate} ) {
        $message->{lastupdate} = time;
    }

    unless ( $message->{hostname} ) {
        $message->{hostname}  = $self->hostname;
    }

    my $message_text = Dump $message;

    my $time = $message->{lastupdate};
    my $date = strftime( "%a, %d %b %Y %H:%M:%S %z", localtime( $time ) );

    my $subject;
    if ( $message->{key} ) {
        $subject = join( ": ", $message->{key}, $message->{subject} || $date );
    }
    else {
        $subject = $message->{subject} || $date;
    }

    $self->sqlite->{ $dbfile }->insert( 'message_queue',
                                        { date       => $date,
                                          subject    => $subject,
                                          data       => $message_text,
                                          hostname   => $message->{hostname},
                                          seen       => undef,
                                          lastupdate => $time,
                                          key        => $message->{key} || "",
                                      },
                                    );

    return 1;
}

sub delete_seen {
   my ( $self, $directory, $age ) = @_;

   my $dbfile = "$directory/queue.sqlite";

   unless ( -r $dbfile ) {
       $self->logger->debug( "ERROR: dbfile not found: $dbfile" );
       return;
   }

   unless ( $self->sqlite->{ $dbfile } ) {
       $self->initialize_db( $directory );
   }

   my $time = time;
   if ( $age ) { $time -= $age }
   $self->logger->warn( "Deleting items from message queue that are older than: ", scalar localtime $time );

   my $conditions = { seen => { '<' => $time } };
   $self->sqlite->{ $dbfile }->delete( 'message_queue', $conditions );
}

sub get {
    my ( $self, $directory ) = @_;

    my $dbfile = "$directory/queue.sqlite";

    unless ( -r $dbfile ) {
        $self->logger->debug( "ERROR: dbfile not found: $dbfile" );
        return;
    }

    # if we don't have a sqlite object for this file, create one now
    unless ( $self->sqlite->{ $dbfile } ) {
        $self->initialize_db( $directory );
    }

    my ( $entry ) = $self->sqlite->{ $dbfile }->query( "SELECT * FROM message_queue WHERE seen IS NULL ORDER BY id LIMIT 1" );

    return unless $entry;

    my $message;
    eval {                          # try
        $message = Load $entry->{data};
        1;
    } or do {                       # catch
        # error
        my $error = $@;
        $self->logger->error( "ERROR LOADING MESSAGE: $entry->{id} => $entry->{subject}: $error" );

        $self->sqlite->{ $dbfile }->insert( 'message_queue_rejected',
                                            $entry,
                                        );

        $self->sqlite->{ $dbfile }->delete( 'message_queue', { id => $entry->{id} } );

        $message = { subject => "LocalMessageStore: rejected $entry->{id}: $entry->{subject}",
                     errmsg  => $error,
                 };

    };


    # if called in array context, return the message and a callback
    # method to delete the item from the queue AFTER it has been
    # processed.
    if ( wantarray ) {
        my $callback = sub { $self->sqlite->{ $dbfile }->update( 'message_queue', { seen => time }, { id => $entry->{id} } ) };
        $self->logger->trace( "Marking message_queue id seen: $entry->{id}: ", time );
        return ( $message, $callback );
    }

    $self->sqlite->{ $dbfile }->delete( 'message_queue', { id => $entry->{id} } );
    return $message;
}

sub get_counts {
    my ( $self, $directory ) = @_;

    my $dbfile = "$directory/queue.sqlite";

    unless ( -r $dbfile ) {
        $self->logger->debug( "ERROR: dbfile not found: $dbfile" );
        return;
    }

    # if we don't have a sqlite object for this file, create one now
    unless ( $self->sqlite->{ $dbfile } ) {
        $self->initialize_db( $directory );
    }

    my ( $seen   ) = $self->sqlite->{ $dbfile }->query( "SELECT count(*) FROM message_queue WHERE seen IS NOT NULL" );
    my ( $unseen ) = $self->sqlite->{ $dbfile }->query( "SELECT count(*) FROM message_queue WHERE seen IS NULL" );

    my $seen_count   = $seen->{'count(*)'}   || 0;
    my $unseen_count = $unseen->{'count(*)'} || 0;

    return ( $seen_count, $unseen_count, $seen_count + $unseen_count );
}

sub checksum {
    my ( $self, $message ) = @_;

    return unless $message;

    my $text = YAML::XS::Dump $message;

    utf8::encode( $text );

    return md5_hex( $text );
}

1;
