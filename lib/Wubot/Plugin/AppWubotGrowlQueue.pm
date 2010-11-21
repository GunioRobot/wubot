package Wubot::Plugin::AppWubotGrowlQueue;
use Moose;

use DBI;
use DBD::Pg;
use Growl::Tiny;
use Log::Log4perl;
use SQL::Abstract;
use Term::ANSIColor;
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

my $valid_colors = { blue    => 'blue',
                     cyan    => 'cyan',
                     red     => 'red',
                     white   => 'white',
                     green   => 'green',
                     orange  => 'yellow',
                     yellow  => 'bold yellow',
                     purple  => 'magenta',
                     magenta => 'magenta',
                 };

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
        $self->{sth} = $self->{dbh}->prepare( "SELECT * FROM $config->{tablename} ORDER BY id" );

        if ( !defined $self->{sth} ) {
            die "Cannot prepare statement: $DBI::errstr\n";
        }
    }

    $self->{sth}->execute;

    my $count;

    while ( my $notification = $self->{sth}->fetchrow_hashref() ){

        $count++;
        return if $count > $default_limit;

        if ( $notification->{image} ) {
            my $image = $notification->{image};
            $image =~ s|^.*\/||;
            $image = join( "/", $image_dir, $image );
            $notification->{image} = $image;
        }

        Growl::Tiny::notify( $notification );

        my $color = 'white';
        if ( $notification->{color} && $valid_colors->{ $notification->{color} } ) {
            $color = $valid_colors->{ $notification->{color} };
        }

        if ( $notification->{urgent} && $color !~ m/bold/ ) {
            print color "bold $color";
        }
        else {
            print color $color;
        }

        my $subject = $notification->{subject};
        my $title   = $notification->{title};
        utf8::encode( $subject );
        utf8::encode( $title );
        print "growl: ", $title, " => ", $subject . "\n";
        print color 'reset';

        $self->{dbh}->do( "DELETE FROM $config->{tablename} WHERE ID = '$notification->{id}'" )
            or die $self->{dbh}->errstr;

    }

    return ( undef,
             $cache,
         );
}


