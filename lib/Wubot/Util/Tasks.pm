package Wubot::Util::Tasks;
use Moose;

# VERSION

use Date::Manip;
use POSIX qw(strftime);

use Wubot::Logger;
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

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

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


sub get_tasks {
    my ( $self, $due ) = @_;

    my @tasks;

    my $start = time + 15*60;

    my $count;

    my $seen;

    $self->sql->select( { tablename => 'tasks',
                          where     => { 'deadline' => { '<', $start }, status => 'todo' },
                          order     => [ 'priority DESC', 'deadline', 'scheduled', 'lastupdate DESC' ],
                          callback  => sub {
                              my $task = shift;
                              $seen->{$task->{file}}->{$task->{title}} = 1;
                              $task->{subject} = "Past Deadline: $task->{file}.org: $task->{title}\n";

                              $task->{color} = $colors->{deadline}->{ $task->{priority} };

                              $count++;
                              $task->{count} = $count;
                              $task->{deadline_utime} = $task->{deadline};
                              # fixme: due times are off by an hour?
                              $task->{deadline} = strftime( "%Y-%m-%d %H:%M", localtime( $task->{deadline} ) );
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
                              $task->{subject} = "Overdue: $task->{file}.org: $task->{title}\n";

                              $task->{color} = $colors->{due}->{ $task->{priority} };

                              $count++;
                              $task->{count} = $count;
                              # fixme: due times are off by an hour?
                              $task->{scheduled} = strftime( "%Y-%m-%d %H:%M", localtime( $task->{scheduled} ) );
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
                                  $task->{subject} = "Priority: $task->{file}.org: $task->{title}\n";
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
                          where     => { deadline => { '>', $now, '<', $now + 60*15 },
                                         status => 'todo',
                                     },
                          order     => [ 'deadline', 'scheduled', 'priority DESC' ],
                          callback  => sub { my $task = shift;
                                             my $due = strftime( "%l:%M %p", localtime( $task->{deadline} ) );
                                             $task->{subject} = "Deadline: $task->{file}: $task->{title}";
                                             $task->{color}   = 'red';
                                             push @tasks, $task;
                                         },
                      } );

    $self->sql->select( { tablename => 'tasks',
                          where     => { scheduled => { '>', $now, '<', $now + 60*15 },
                                         status    => 'todo',
                                     },
                          order     => [ 'scheduled', 'priority DESC' ],
                          callback  => sub { my $task = shift;
                                             my $due = strftime( "%l:%M %p", localtime( $task->{scheduled} ) );
                                             $task->{subject} = "Scheduled: $task->{file}: $task->{title}";
                                             $task->{color}   = 'yellow';
                                             push @tasks, $task;
                                         },
                      } );

    return @tasks;
}

sub parse_emacs_org_page {
    my ( $self, $orig_filename, $content ) = @_;

    $self->logger->debug( "Parsing $orig_filename" );

    my $filename = $orig_filename;
    $filename =~ s|.org$||;

    my $color = '';

    my @tasks;

  BLOCK:
    for my $block ( split /(?:^|\n)\*+\s/, $content ) {
        $self->logger->trace( "Parsing block: $block" );

        $block =~ s|^\s*\*\s+||mg;

        $block =~ m|^(\w+)|;
        my $name = $1;

        next unless $name;

        if ( $name =~ m|meta|i ) {
            if ( $block =~ m|^\s+\-\scolor\:\s([\w]+)$|m ) {
                $color = "$1";
            }
            next BLOCK;
        }

        unless ( $name eq "TODO" || $name eq "DONE" ) {
            next BLOCK;
        }

        $self->logger->trace( "Parsing $name item" );

        $block =~ s|^\w+\s+||;

        my $task;
        $task->{type} = 'task';

        my $priorities = { C => 0, B => 1, A => 2 };
        if ( $block =~ s|^\[\#(\w)\]\s|| ) {
            $task->{priority} = $priorities->{ $1 };
        } else {
            $task->{priority} = -1;
        }

        if ( $block =~ s|^((?:\d+[smhd])+)\s|| ) {
            $task->{duration} = $1;
        }

        $task->{status} = lc( $name );

        $task->{file} = $filename;

        $block =~ s|^(.*)||;
        $task->{title} = $1;

        if ( $task->{title} =~ s|\s*\[(\d+.*?)\]\s*$|| ) {
            $task->{progress} = $1;
        }

        $task->{taskid} = join( ".", $task->{file}, $task->{title} );

        # deadline may be listed before or after schedule.
        # this is an ugly solution that gets it either way
        if ( $block =~ s|^\s+DEADLINE\:\s\<(.*?)(?:\s\.?(\+\d+\w))?\>||m ) {
            $task->{deadline_text} = $1;
            $task->{deadline}      = UnixDate( ParseDate( $1 ), "%s" ) - 3600;
            $task->{deadline_recurrence}    = $2;
        }
        if ( $block =~ s|^\s+SCHEDULED\:\s\<(.*?)(?:\s\.?(\+\d+\w))?\>||m ) {
            $task->{scheduled_text} = $1;
            $task->{scheduled}      = UnixDate( ParseDate( $1 ), "%s" ) - 3600;
            $task->{scheduled_recurrence}     = $2;
        }
        if ( $block =~ s|^\s+DEADLINE\:\s\<(.*?)(?:\s\.?(\+\d+\w))?\>||m ) {
            $task->{deadline_text} = $1;
            $task->{deadline}      = UnixDate( ParseDate( $1 ), "%s" ) - 3600;
            $task->{deadline_recurrence}    = $2;
        }

        $block =~ s|^\s+\- State "DONE"\s+from "TODO"\s+\[.*$||mg;

        $block =~ s|^\s+\n||s;

        $task->{body} = $block;
        $task->{body} =~ s|\s+$||s;

        push @tasks, $task;
    }

    if ( $color ) {
        for my $task ( @tasks ) {
            unless ( $task->{color} ) {
                $task->{colro} = $color;
            }
        }
    }

    return @tasks;
}

1;

