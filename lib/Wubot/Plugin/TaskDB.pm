package Wubot::Plugin::TaskDB;
use Moose;

use DBI;
use POSIX qw(strftime);

use Wubot::SQLite;

has 'sql'    => ( is      => 'ro',
                  isa     => 'Wubot::SQLite',
                  lazy    => 1,
                  default => sub {
                      return Wubot::SQLite->new( { file => $_[0]->dbfile } );
                  },
              );

has 'dbfile' => ( is      => 'rw',
                  isa     => 'Str',
              );

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    $self->dbfile( $config->{dbfile} );

    my $now = time;

    my $task;

    unless ( $task ) {
        $self->sql->select( { tablename => $config->{tablename},
                              where     => { 'deadline' => { '<', $now }, status => 'todo' },
                              order     => [ 'deadline', 'scheduled', 'priority DESC' ],
                              limit     => 1,
                              callback  => sub { $task = $_[0] },
                          } );
        if ( $task ) {
            $task->{subject} = "Past Deadline: $task->{file}.org => $task->{title} => $task->{deadline_text}\n";
            $task->{color}   = 'red';
        }
    }

    unless ( $task ) {
        $self->sql->select( { tablename => $config->{tablename},
                              where     => { 'scheduled' => { '<', $now }, status => 'todo' },
                              order     => [ 'scheduled', 'priority DESC' ],
                              limit     => 1,
                              callback  => sub { $task = $_[0] },
                          } );
        if ( $task ) {
            $task->{subject} = "Overdue: $task->{file}.org => $task->{title} => $task->{scheduled_text}\n";
            $task->{color}   = 'yellow';
        }
    }

    if ( $task ) {

        if ( $cache->{lasttask} && $cache->{lasttask} eq $task->{subject} ) {

            # task hasn't changed.  if we've already sent a
            # notification in the last 15 minutes, don't send another.
            if ( $cache->{lastnotify} && time - $cache->{lastnotify} < 900 ) {
                return;
            }

        }
        else {
            # if this is a new task, set the 'sticky' bit on for the notification
            $task->{sticky} = 1;
        }

        # cache the last task
        $cache->{lasttask}   = $task->{subject};
        $cache->{lastnotify} = time;

        return { react => $task,
                 cache => $cache,
             };
    }

    return;
}


1;
