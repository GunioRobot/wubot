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

    unless ( $task ) {
        $self->sql->select( { tablename => $config->{tablename},
                              order     => [ 'priority', 'lastupdate' ],
                              where     => { scheduled => undef, deadline => undef, status => 'todo' },
                              limit     => 1,
                              callback  => sub { $task = $_[0] },
                          } );

        if ( $task ) {
            $task->{subject} = "Top task: $task->{file}.org => $task->{title}\n";
            $task->{color}   = 'blue';
        }
    }

    if ( $task ) {
        return { react => $task };
    }

    return;
}


1;
