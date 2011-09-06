package App::Wubot::Plugin::TaskNotify;
use Moose;

# VERSION

use POSIX qw(strftime);

use App::Wubot::Logger;
use App::Wubot::Util::Tasks;

with 'App::Wubot::Plugin::Roles::Cache';
with 'App::Wubot::Plugin::Roles::Plugin';

my $taskutil   = App::Wubot::Util::Tasks->new();

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

__END__

=head1 NAME

App::Wubot::Plugin::TaskNotify - monitor for upcoming scheduled tasks

=head1 SYNOPSIS

  ~/wubot/config/plugins/TaskNotify/org.yaml

  ---
  dbfile: /Users/wu/wubot/sqlite/tasks.sql
  tablename: tasks
  delay: 5m


=head1 DESCRIPTION

The TaskNotify plugin looks in the tasks database for items that are
within 15 minutes of coming due.  For each item, a notification is
sent each time the plugin runs.


=head1 SUBROUTINES/METHODS

=over 8

=item check( $inputs )

The standard monitor check() method.

=back
