package Wubot::Web::Tasks;
use Mojo::Base 'Mojolicious::Controller';

use POSIX qw(strftime);
use URI::Escape;

use Wubot::Util::Tasks;
use Wubot::Util::Colors;

my $sqlite_tasks = Wubot::SQLite->new( { file => '/Users/wu/wubot/sqlite/tasks.sql' } );
my $taskutil     = Wubot::Util::Tasks->new();
my $colors       = Wubot::Util::Colors->new();

sub tasks {
    my $self = shift;

    my $due = $self->param( 'due' );

    my @tasks = $taskutil->get_tasks( $due );

    my $now = time;

    for my $task ( @tasks ) {

        $task->{lastupdate} = strftime( "%Y-%m-%d %H:%M", localtime( $task->{lastupdate} ) );

        if ( $task->{deadline_utime} ) {
            my $diff = abs( $task->{deadline_utime} - $now );
            if ( $diff < 3600 ) {
                $task->{color} = "green";
            }
            elsif ( $diff < 900 ) {
                $task->{color} = "pink";
            }
        }

        if ( $colors->get_color( $task->{color} ) ) {
            $task->{color} = $colors->get_color( $task->{color} );
        }

        if ( $task->{duration} ) {
            $task->{emacs_link} = join( "%20", $task->{duration}, $task->{title} );
        }
        else {
            $task->{emacs_link} = $task->{title};
        }
        $task->{emacs_link} =~ s|\/|__SLASH__|g;
        $task->{emacs_link} = uri_escape( $task->{emacs_link} );
    }

    $self->stash( 'headers', [qw/count lastupdate file title priority scheduled deadline/ ] );

    $self->stash( 'body_data', \@tasks );

    $self->render( template => 'tasks' );

};

sub open {
    my $self = shift;

    my $filename = $self->stash( 'file' );
    $filename =~ tr/A-Za-z0-9\.\-\_//cd;
    print "FILENAME: $filename\n";

    my $link = uri_unescape( $self->stash( 'link' ) );
    $link =~ s|[\'\"]|.|g;
    $link =~ s|__SLASH__|/|g;
    $link = "file:/Users/wu/org/$filename\:\:$link";

    my $command;
    if ( $self->param('done') ) {
        my $emacs_foo = qq{ (progn (org-open-link-from-string "[[$link]]" )(pop-to-buffer "$filename")(delete-other-windows)(org-todo)(save-buffer)(raise-frame)) };
        $command = qq(emacsclient --socket-name /tmp/emacs501/server -e '$emacs_foo' &);
    }
    else {
        my $emacs_foo = qq{ (progn (org-open-link-from-string "[[$link]]" )(pop-to-buffer "$filename")(delete-other-windows)(raise-frame)) };
        $command = qq(emacsclient --socket-name /tmp/emacs501/server -e '$emacs_foo' &);
    }

    print "EMACS: $command\n";
    system( $command );

    # switch to x11 emacs
    system( qq{osascript -e 'tell app "X11" to activate'} );

    $self->redirect_to( "/tasks?due=1" );
};

1;
