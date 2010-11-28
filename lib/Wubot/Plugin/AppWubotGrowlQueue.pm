package Wubot::Plugin::AppWubotGrowlQueue;
use Moose;

use DBI;
use DBD::Pg;
use Growl::Tiny;
use YAML;

with 'Wubot::Plugin::Roles::Plugin';
with 'Wubot::Plugin::Roles::Cache';

my $default_limit = 10;

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

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

    # delete any ids that were previously marked for deletion.
    if ( $cache->{deleteme} ) {
        for my $id ( keys %{ $cache->{deleteme} } ) {

            $self->{dbh}->do( "DELETE FROM $config->{tablename} WHERE id = $id" )
                or die $self->{dbh}->errstr;

            delete $cache->{deleteme}->{$id};
        }
    }

    unless ( $self->{sth} ) {
        $self->{sth} = $self->{dbh}->prepare( "SELECT * FROM $config->{tablename} ORDER BY id" );

        if ( !defined $self->{sth} ) {
            die "Cannot prepare statement: $DBI::errstr\n";
        }
    }

    $self->{sth}->execute;

    my @results;

    my $count;

    while ( my $notification = $self->{sth}->fetchrow_hashref() ){

        $count++;
        return if $count > $default_limit;

        # set the hostname that the message came from, prevents
        # routing the message back to wubot which would cause an
        # infinite loop
        $notification->{hostname} = "wubot";

        push @results, $notification;

        # mark these ids for deletion next time this check runs.  we
        # don't want to delete them immediately or else we risk the
        # possibility that they may never be delivered.  This is the
        # reason that the cache won't be written until after the
        # reaction messages are sent.
        $cache->{deleteme}->{ $notification->{id} } = 1;
    }

    return { cache => $cache, react => \@results };
}


