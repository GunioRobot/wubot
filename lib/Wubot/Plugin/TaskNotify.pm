package Wubot::Plugin::TaskNotify;
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

has 'delay_count' => ( is => 'ro',
                       isa => 'HashRef',
                       lazy => 1,
                       default => sub { {} },
                   );

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    $self->dbfile( $config->{dbfile} );

    my $now = time;

    my @tasks;
    $self->sql->select( { tablename => $config->{tablename},
                          where     => { deadline => { '>', $now - 60, '<', $now + 60*15 },
                                         status => 'todo',
                                     },
                          order     => [ 'deadline', 'scheduled', 'priority DESC' ],
                          callback  => sub { my $task = shift;
                                             my $due = strftime( "%l:%M %p", localtime( $task->{deadline} ) );
                                             $task->{subject} = "Deadline: $task->{file} => $task->{title}";
                                             $task->{color}   = 'red';
                                             push @tasks, $task;
                                         },
                      } );

    $self->sql->select( { tablename => $config->{tablename},
                          where     => { scheduled => { '>', $now - 60, '<', $now + 60*15 },
                                         status    => 'todo',
                                     },
                          order     => [ 'scheduled', 'priority DESC' ],
                          callback  => sub { my $task = shift;
                                             my $due = strftime( "%l:%M %p", localtime( $task->{scheduled} ) );
                                             $task->{subject} = "Scheduled: $task->{file} => $task->{title}";
                                             $task->{color}   = 'yellow';
                                             push @tasks, $task;
                                         },
                      } );

    for my $task ( @tasks ) {
        $task->{count}  = $self->delay_count->{ $task->{title} } || 0;

        # use current time for notification, not lastupdate time on record
        delete $task->{lastupdate};

        return unless  $task->{count} % 5 == 0;

        $task->{sticky} = 1;
        $task->{urgent} = 1;

        $self->delay_count->{ $task->{title} }++;

        # growl identifier for coalescing
        $task->{growl_id} = $task->{title};
    }

    return { react => \@tasks };
}


1;
