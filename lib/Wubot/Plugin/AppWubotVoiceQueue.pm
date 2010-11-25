package Wubot::Plugin::AppWubotVoiceQueue;
use Moose;

use DBI;
use DBD::Pg;
use Growl::Tiny;
use Log::Log4perl;
use SQL::Abstract;
use YAML;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

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
        my $text = $entry->{text};

        for my $text ( keys %{ $config->{word_fix} } ) {
            $text =~ s/\b$text\b/$config->{word_fix}->{$text}/i;
        }

        my $rate  = $config->{voice_rate} || 350;
        my $voice = $config->{voice} || 'zarvox';

        $self->logger->info( "transformed text: $text" );

        system( '/usr/bin/say', '-v', $voice, "[[rate $rate]] $text" );
        $sql->delete( 'notify_voice', { id => $entry->{id} } );

        $self->{dbh}->do( "DELETE FROM $config->{tablename} WHERE ID = '$entry->{id}'" )
            or die $self->{dbh}->errstr;
    }

    return $cache;
}


