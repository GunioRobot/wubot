package Wubot::Plugin::TaskDB;
use Moose;

use DBI;
use POSIX qw(strftime);

use Wubot::Util::Tasks;
my $taskutil   = Wubot::Util::Tasks->new();

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    my $now = time;

    my @tasks = $taskutil->get_tasks();

    return unless scalar @tasks;

    my $task = $tasks[0];

    if ( $cache->{lasttask} && $cache->{lasttask} eq $task->{subject} ) {

        # task hasn't changed.  if we've already sent a
        # notification in the last 30 minutes, don't send another.
        if ( $cache->{lastnotify} && time - $cache->{lastnotify} < 1800 ) {
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


1;
