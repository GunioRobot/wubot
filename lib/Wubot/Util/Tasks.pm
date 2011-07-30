package Wubot::Util::Tasks;
use Moose;

# VERSION

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
    my ( $self, $due ) = @_;

    my @tasks;

    my $start = time + 15*60;

    my $count;

    my $seen;

    my $colors = { deadline => { 2  => '#CC3300',
                                 1  => '#BB2200',
                                 0  => '#AA1100',
                                 -1 => '#990000',
                                 },
                   due      => { 2  => '#CC9900',
                                 1  => '#BB8800',
                                 0  => '#AA7700',
                                 -1 => '#996600',
                             },
               };

    $self->sql->select( { tablename => 'tasks',
                          where     => { 'deadline' => { '<', $start }, status => 'todo' },
                          order     => [ 'priority DESC', 'deadline', 'scheduled', 'lastupdate DESC' ],
                          callback  => sub {
                              my $task = shift;
                              $seen->{$task->{file}}->{$task->{title}} = 1;
                              $task->{subject} = "Past Deadline: $task->{file}.org => $task->{title}\n";

                              $task->{color} = $colors->{deadline}->{ $task->{priority} };

                              $count++;
                              $task->{count} = $count;
                              $task->{deadline_utime} = $task->{deadline};
                              # fixme: due times are off by an hour?
                              $task->{deadline} = strftime( "%Y-%m-%d %H:%M", localtime( $task->{deadline} - 3600 ) );
                              $task->{urgent} = 1;
                              push @tasks, $task;
                          },
                      } );

    $self->sql->select( { tablename => 'tasks',
                          where     => { 'scheduled' => { '<', $start }, status => 'todo' },
                          order     => [ 'priority DESC', 'scheduled', 'lastupdate DESC' ],
                          callback  => sub {
                              my $task = shift;
                              return if $seen->{$task->{file}}->{$task->{title}};
                              $seen->{$task->{file}}->{$task->{title}} = 1;
                              $task->{subject} = "Overdue: $task->{file}.org => $task->{title}\n";

                              $task->{color} = $colors->{due}->{ $task->{priority} };

                              $count++;
                              $task->{count} = $count;
                              # fixme: due times are off by an hour?
                              $task->{scheduled} = strftime( "%Y-%m-%d %H:%M", localtime( $task->{scheduled} - 3600 ) );
                              push @tasks, $task;
                          },
                      } );

    my $priority_colors = { 2 => 'yellow', 1 => 'blue', 0 => 'green' };
    unless ( $due ) {
        $self->sql->select( { tablename => 'tasks',
                              where     => { 'priority' => { '>', -1 }, scheduled => undef, deadline => undef, status => 'todo' },
                              order     => [ 'priority DESC', 'lastupdate DESC' ],
                              callback  => sub {
                                  my $task = shift;
                                  next if $seen->{$task->{file}}->{$task->{title}};
                                  $seen->{$task->{file}}->{$task->{title}} = 1;
                                  $task->{subject} = "Priority: $task->{file}.org => $task->{title}\n";
                                  $task->{color}   = $priority_colors->{ $task->{priority} };
                                  $count++;
                                  $task->{count} = $count;
                                  push @tasks, $task;
                              },
                          } );
    }

    return @tasks;

}

sub check_schedule {
    my ( $self ) = @_;

    my $now = time;

    my @tasks;
    $self->sql->select( { tablename => 'tasks',
                          where     => { deadline => { '>', $now - 60, '<', $now + 60*15 },
                                         status => 'todo',
                                     },
                          order     => [ 'deadline', 'scheduled', 'priority DESC' ],
                          callback  => sub { my $task = shift;
                                             my $due = strftime( "%l:%M %p", localtime( $task->{deadline} - 3600 ) );
                                             $task->{subject} = "Deadline: $task->{file} => $task->{title}";
                                             $task->{color}   = 'red';
                                             push @tasks, $task;
                                         },
                      } );

    $self->sql->select( { tablename => 'tasks',
                          where     => { scheduled => { '>', $now - 60, '<', $now + 60*15 },
                                         status    => 'todo',
                                     },
                          order     => [ 'scheduled', 'priority DESC' ],
                          callback  => sub { my $task = shift;
                                             my $due = strftime( "%l:%M %p", localtime( $task->{scheduled} - 3600 ) );
                                             $task->{subject} = "Scheduled: $task->{file} => $task->{title}";
                                             $task->{color}   = 'yellow';
                                             push @tasks, $task;
                                         },
                      } );

    return @tasks;
}

1;

