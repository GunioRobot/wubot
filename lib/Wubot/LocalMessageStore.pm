package Wubot::LocalMessageStore;
use Moose;

# todo - warn if queue length above a certain size

use Digest::MD5 qw( md5_hex );
use Wubot::SQLite;
use Log::Log4perl;
use POSIX qw(strftime);
use Sys::Hostname qw();
use YAML;

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



sub store {
    my ( $self, $message, $directory ) = @_;

    my $dbfile = "$directory/queue.sqlite";

    # if we don't have a sqlite object for this file, create one now
    unless ( $self->sqlite->{ $dbfile } ) {
        $self->sqlite->{ $dbfile } = Wubot::SQLite->new( { file => "$dbfile" } );
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

    my $message_text = YAML::Dump $message;
    utf8::encode( $message_text );

    my $time = $message->{lastupdate};
    my $date = strftime( "%a, %d %b %Y %H:%M:%S %z", localtime( $time ) );

    my $subject = join( ": ", $message->{key}, $message->{subject} || $date );

    $self->sqlite->{ $dbfile }->insert( 'message_queue',
                                        { date     => $date,
                                          subject  => $subject,
                                          data     => $message_text,
                                          hostname => $message->{hostname},
                                          seen     => undef,
                                      },
                                        { id       => 'INTEGER PRIMARY KEY AUTOINCREMENT',
                                          date     => 'VARCHAR(32)',
                                          subject  => 'VARCHAR(256)',
                                          data     => 'TEXT',
                                          hostname => 'VARCHAR(32)',
                                          seen     => 'INTEGER',
                                      }
                                    );

    return 1;
}

sub get {
    my ( $self, $directory ) = @_;

    my $dbfile = "$directory/queue.sqlite";

    return unless -r $dbfile;

    # if we don't have a sqlite object for this file, create one now
    unless ( $self->sqlite->{ $dbfile } ) {
        $self->sqlite->{ $dbfile } = Wubot::SQLite->new( { file => "$dbfile" } );
    }

    my ( $entry ) = $self->sqlite->{ $dbfile }->query( "SELECT * FROM message_queue WHERE seen IS NULL ORDER BY id LIMIT 1" );

    return unless $entry;

    my $message = YAML::Load $entry->{data};

    # if called in array context, return the message and a callback
    # method to delete the item from the queue AFTER it has been
    # processed.
    if ( wantarray ) {
        my $callback = sub { $self->sqlite->{ $dbfile }->update( 'message_queue', { seen => 1 }, { id => $entry->{id} } ) };
        return ( $message, $callback );
    }

    $self->sqlite->{ $dbfile }->delete( 'message_queue', { id => $entry->{id} } );
    return $message;
}

sub checksum {
    my ( $self, $message ) = @_;

    my $text = YAML::Dump $message;

    utf8::encode( $text );

    return md5_hex( $text );
}

1;
