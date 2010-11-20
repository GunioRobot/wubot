package Wubot::Plugin::AppWubotVoiceQueue;
use Moose;

use DBI;
use DBD::Pg;
use Growl::Tiny;
use SQL::Abstract;
use YAML;

my $image_dir = '/Users/wu/.icons';
my $default_limit = 10;

my $sql = SQL::Abstract->new;

sub check {
    my ( $self, $config, $cache ) = @_;

    unless ( $self->{dbh} ) {
        $self->{dbh} = DBI->connect("dbi:Pg:dbname=$config->{dbname};host=$config->{host};port=$config->{port};options=''",
                                    $config->{user},
                                    "",
                                    { AutoCommit         => 1,
                                      RaiseError         => 1,
                                      PrintError         => 1,
                                      ChopBlanks         => 1,
                                      ShowErrorStatement => 0,
                                      pg_enable_utf8     => 1,
                                  } );
    }

    unless ( $self->{sth} ) {
        $self->{sth} = $self->{dbh}->prepare( "SELECT * FROM $config->{tablename} ORDER BY timestamp DESC LIMIT 1" );

        if ( !defined $self->{sth} ) {
            die "Cannot prepare statement: $DBI::errstr\n";
        }
    }

    $self->{sth}->execute;

    while ( my $entry = $self->{sth}->fetchrow_hashref() ){
        print "Voice: $entry->{text}\n";

        my $text = $entry->{text};

        $text =~ s|\bcci\b| CCI |g;
        $text =~ s|\birc\b| IRC |g;
        $text =~ s|\bwubot\b| wubot |g;
        $text =~ s|\but3\b| U T 3 |g;
        $text =~ s|\bbuji\b| booji |g;
        $text =~ s|\bswt\b| sweeet |g;

        system( '/usr/bin/say', $text );
        $sql->delete( 'notify_voice', { id => $entry->{id} } );

        $self->{dbh}->do( "DELETE FROM $config->{tablename} WHERE ID = '$entry->{id}'" )
            or die $self->{dbh}->errstr;
    }

    return ( undef,
             $cache,
         );
}


