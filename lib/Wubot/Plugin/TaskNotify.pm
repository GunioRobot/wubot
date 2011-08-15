package Wubot::Plugin::TaskNotify;
use Moose;

# VERSION

use POSIX qw(strftime);

use Wubot::Logger;
use Wubot::Util::Tasks;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

my $taskutil   = Wubot::Util::Tasks->new();

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    my @tasks = $taskutil->check_schedule();

    for my $task ( @tasks ) {

        # use current time for notification, not lastupdate time on record
        delete $task->{lastupdate};

        $task->{sticky} = 1;
        $task->{urgent} = 1;

        # growl identifier for coalescing
        $task->{growl_id} = $task->{title};

        $task->{link} = "/tasks";
    }

    return { react => \@tasks };
}


1;
