package Wubot::Reactor::Command;
use Moose;

# VERSION

use File::Path;
use Log::Log4perl;
use POSIX qw(strftime setsid :sys_wait_h);
use Term::ANSIColor;

use Wubot::LocalMessageStore;

has 'logger'   => ( is       => 'ro',
                    isa      => 'Log::Log4perl::Logger',
                    lazy     => 1,
                    default  => sub {
                        return Log::Log4perl::get_logger( __PACKAGE__ );
                    },
                );

has 'logdir'   => ( is       => 'ro',
                    isa      => 'Str',
                    lazy     => 1,
                    default  => sub {
                        my $self = shift;
                        return join( "/", $ENV{HOME}, "wubot", "commands" );
                    },
                );

has 'queue'   => ( is      => 'ro',
                     isa     => 'Wubot::LocalMessageStore',
                     lazy    => 1,
                     default => sub {
                         return Wubot::LocalMessageStore->new();
                     },
                 );

has 'queuedir'  => ( is       => 'ro',
                     isa      => 'Str',
                     lazy     => 1,
                     default  => sub {
                         my $self = shift;
                         return join( "/", $ENV{HOME}, "wubot", "sqlite", "command" );
                     },
                 );




sub react {
    my ( $self, $message, $config ) = @_;

    my $output = "";

    my $command;
    if ( $config->{command} ) {
        $self->logger->debug( "Running configured command: $config->{command}" );
        $command = $config->{command};
    }
    elsif ( $config->{command_field} ) {
        $command = $message->{ $config->{command_field} };

        unless ( $command ) {
            $self->logger->error( "ERROR: command_field $config->{command_field} is blank, no command executed" );
            return $message;
        }

        $self->logger->debug( "Running command field: $config->{command_field}: $command " );
        $output = `$command 2>&1`;
    }
    else {
        $self->logger->error( "Command reactor error: no command or command_field specified in config" );
        return $message;
    }

    if ( $config->{fork} ) {
        return $self->fork_or_enqueue( $command, $message, $config );
    }
    else {
        $output = `$command 2>&1`;
    }

    chomp $output;

    if ( $config->{output_field} ) {
        $message->{ $config->{output_field} } = $output;
    }
    else {
        $message->{command_output} = $output;
    }

    return $message;
}

sub monitor {
    my ( $self ) = @_;

    # clean up any child processes that have exited
    waitpid(-1, WNOHANG);

    my @messages;

    my $directory = $self->logdir;

    my $dir_h;
    opendir( $dir_h, $directory ) or die "Can't opendir $directory: $!";

    FILE:
    while ( defined( my $entry = readdir( $dir_h ) ) ) {
        next unless $entry;
        next if -d $entry;

        next unless $entry =~ m|\.log$|;
        $self->logger->info( "Found entry: $entry" );

        my $id = $entry;
        $id =~ s|\.log$||;

        next if $self->check_process( $id );

        my $logfile = "$directory/$id.log";

        open(my $fh, "<", $logfile)
            or die "Couldn't open $logfile for reading: $!\n";
        my $output = "";

        while ( my $line = <$fh> ) {
            $output .= $line;
        }
        close $fh or die "Error closing file: $!\n";

        next FILE unless $output;

        chomp $output;

        my $message;
        $message->{command_output} = $output;

        push @messages, $message;

        # TODO: hole here where message could be lost after the log is deleted!

        unlink( $logfile );;
    }

    closedir( $dir_h );

    # start commands
  QUEUE:
    while ( my ( $message, $callback ) = $self->queue->get( $self->queuedir ) ) {

        if ( -r $message->{pidfile} ) {
            $self->logger->debug( "Previous process not yet cleaned up: $message->{pidfile}" );
            next QUEUE;
        }
        if ( -r $message->{logfile} ) {
            $self->logger->debug( "Previous logfile not yet cleaned up: $message->{logfile}" );
        }

        if ( my $message = $self->try_fork( $message ) ) {

            # TODO: react to message
            #push @messages, $message;

            # delete the message from the queue
            $callback->();
        }

    }

    return \@messages;
}

sub fork_or_enqueue {
    my ( $self, $command, $message, $config ) = @_;

    my $id = $config->{fork};

    unless ( -d $self->logdir ) {
        mkpath( $self->logdir );
    }

    my $logfile = join( "/", $self->logdir, "$id.log" );
    my $pidfile = join( "/", $self->logdir, "$id.pid" );

    if ( $self->check_process( $id ) ) {

        my $queue = { logfile    => $logfile,
                      pidfile    => $pidfile,
                      command    => $command,
                      id         => $id,
                      lastupdate => time,
                  };
        $self->queue->store( $queue, $self->queuedir );

        $message->{command_queued} = 1;
        return $message;
    }

    return $self->try_fork( { id      => $id,
                              message => $message,
                              command => $command,
                              logfile => $logfile,
                              pidfile => $pidfile,
                          } );
}

sub try_fork {
    my ( $self, $process ) = @_;

    $self->logger->debug( "TRYING FORK: ", YAML::Dump $process );

    my $message = $process->{message} || {};

    if ( my $pid = fork() ) {
        open(my $fh, ">", $process->{pidfile})
            or die "Couldn't open $process->{pidfile} for writing: $!\n";
        print $fh $pid;
        close $fh or die "Error closing file: $!\n";

        $message->{pidfile}     = $process->{pidfile};
        $message->{logfile}     = $process->{logfile};
        $message->{command_pid} = $pid;
        $message->{id}          = $process->{id};
        return $message;
    }

    $self->logger->info( "Pidfile: $process->{pidfile}" );

    # wu - ugly bug fix - when closing STDIN, it becomes free and
    # may later get reused when calling open (resulting in error
    # 'Filehandle STDIN reopened as $fh only for output'). :/ So
    # instead of closing, just re-open to /dev/null.
    open STDIN, '<', '/dev/null'       or die "$!";

    if ( -r $process->{logfile} ) {
        unlink $process->{logfile};
    }

    open STDOUT, '>>', $process->{logfile} or die "Can't write stdout to $process->{logfile}: $!";
    open STDERR, '>>', $process->{logfile} or die "Can't write stderr to $process->{logfile}: $!";

    setsid or die "Can't start a new session: $!";

    system( $process->{command} );

    unlink( $process->{pidfile} );

    close STDOUT;
    close STDERR;

    exit;
}

sub check_process {
    my ( $self, $id ) = @_;

    my $pidfile = join( "/", $self->logdir, "$id.pid" );

    unless ( -r $pidfile ) {
        $self->logger->info( "Pidfile not found: $pidfile" );
        return;
    }

    open(my $fh, "<", $pidfile)
        or die "Couldn't open $pidfile for reading: $!\n";
    my $pid = <$fh>;
    close $fh or die "Error closing file: $!\n";
    return unless $pid;

    if ( kill 0 => $pid ) {
        $self->logger->info( "Process responded to kill 0: $pid" );
        return 1;
    }

    $self->logger->info( "Pidfile exists but pid not active: $pid" );
    unlink( $pidfile );

    return;
}

1;
