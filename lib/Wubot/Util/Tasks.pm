package Wubot::Util::Tasks;
use Moose;

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
                  lazy    => 1,
                  default => sub {
                      return join( "/", $ENV{HOME}, "wubot", "sqlite", "tasks.sql" );
                  },
              );

sub get_tasks {
    my ( $self ) = @_;

    my @tasks;

    my $start = time + 15*60;

    my $count;

    $self->sql->select( { tablename => 'tasks',
                          where     => { 'deadline' => { '<', $start }, status => 'todo' },
                          order     => [ 'priority DESC', 'deadline', 'scheduled' ],
                          callback  => sub {
                              my $task = shift;
                              $task->{subject} = "Past Deadline: $task->{file}.org => $task->{title}\n";
                              $task->{color}   = 'red';
                              $count++;
                              $task->{count} = $count;
                              $task->{deadline} = strftime( "%Y-%m-%d %H:%M", localtime( $task->{deadline} ) );
                              $task->{urgent} = 1;
                              push @tasks, $task;
                          },
                      } );

    $self->sql->select( { tablename => 'tasks',
                          where     => { 'scheduled' => { '<', $start }, status => 'todo' },
                          order     => [ 'priority DESC', 'scheduled' ],
                          callback  => sub {
                              my $task = shift;
                              $task->{subject} = "Overdue: $task->{file}.org => $task->{title}\n";
                              $task->{color}   = 'yellow';
                              $count++;
                              $task->{count} = $count;
                              $task->{scheduled} = strftime( "%Y-%m-%d %H:%M", localtime( $task->{scheduled} ) );
                              push @tasks, $task;
                          },
                      } );

    return @tasks;

}


1;

