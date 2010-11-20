package Wubot::Monitor::Plugin::AppWubotGrowlQueue;
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

        print "Growl: $notification->{subject}\n";

        if ( $notification->{image} ) {
            my $image = $notification->{image};
            $image =~ s|^.*\/||;
            $image = join( "/", $image_dir, $image );
            $notification->{image} = $image;
        }

        Growl::Tiny::notify( $notification );

        $self->{dbh}->do( "DELETE FROM $config->{tablename} WHERE ID = '$notification->{id}'" )
            or die $self->{dbh}->errstr;
    }

    return ( undef,
             $cache,
         );
}


