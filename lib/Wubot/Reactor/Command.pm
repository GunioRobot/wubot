package Wubot::Reactor::Command;
use Moose;

# VERSION

use FileHandle;
use File::Path;
use Log::Log4perl;
use POSIX qw(strftime setsid :sys_wait_h);
use Term::ANSIColor;
use YAML::XS;

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

# for use by child processes only
my $child;


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
    }
    else {
        $self->logger->error( "Command reactor error: no command or command_field specified in config" );
        return $message;
    }

    if ( $config->{fork} ) {
        return $self->fork_or_enqueue( $command, $message, $config );
    }

    $output = `$command 2>&1`;
    chomp $output;

    my $results = $?;

    # check exit status
    my $status = 0;
    my $signal = 0;

    unless ( $? eq 0 ) {
        $status = $? >> 8;
        $signal = $? & 127;
        $self->logger->error( "Error running command: $command\n\tstatus=$status\n\tsignal=$signal" );
    }


    if ( $config->{output_field} ) {
        $message->{ $config->{output_field} } = $output;
    }
    else {
        $message->{command_output} = $output;
    }

    $message->{command_signal} = $signal;
    $message->{command_status} = $status;

    return $message;
}

sub monitor {
    my ( $self ) = @_;

    # clean up any child processes that have exited
    $self->logger->trace( "Command: killing zombies" );
    waitpid(-1, WNOHANG);

    my @messages;

    my $directory = $self->logdir;

    my $dir_h;
    opendir( $dir_h, $directory ) or $self->logger->logdie( "Can't opendir $directory: $!" );

    FILE:
    while ( defined( my $entry = readdir( $dir_h ) ) ) {
        next unless $entry;
        next if -d $entry;

        next unless $entry =~ m|\.log$|;
        $self->logger->debug( "Command: found running entry: $entry" );

        my $id = $entry;
        $id =~ s|\.log$||;

        next if $self->check_process( $id );

        $self->logger->info( "Command: collecting finish process info for $id" );

        my $logfile = "$directory/$id.log";

        my $output = "";
        if ( -r $logfile ) {
            $self->logger->info( "Reading command output from logfile: $logfile" );
            open(my $fh, "<", $logfile)
                or die "Couldn't open $logfile for reading: $!\n";
            while ( my $line = <$fh> ) {
                $output .= $line;
            }
            close $fh or die "Error closing file: $!\n";
            chomp $output;
        }

        my $message;
        $message->{command_output} = $output;

        my $statusfile = "$directory/$id.status";
        if ( -r $statusfile ) {
            $self->logger->info( "Loading status file: $statusfile" );
            my $status = YAML::XS::LoadFile( $statusfile );

            for my $key ( keys %{ $status } ) {
                $message->{$key} = $status->{$key};
            }
            for my $key ( keys %{ $status->{message} } ) {
                unless ( $message->{$key} ) {
                    $message->{$key} = $status->{message}->{$key};
                }
            }
            delete $message->{message};

            unlink $statusfile;
        }

        push @messages, $message;

        # TODO: hole here where message could be lost after the log is deleted!

        unlink( $logfile );;
    }

    closedir( $dir_h );

    $self->logger->debug( "Searching for processes in queue to be started" );
  QUEUE:
    while ( my ( $message, $callback ) = $self->queue->get( $self->queuedir ) ) {

        if ( -r $message->{pidfile} ) {
            $self->logger->debug( "Previous process still running: $message->{pidfile}" );
            last QUEUE;
        }
        if ( -r $message->{logfile} ) {
            $self->logger->debug( "Previous logfile not yet cleaned up: $message->{logfile}" );
            last QUEUE;
        }

        if ( my $results = $self->try_fork( $message ) ) {

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

        $self->logger->info( "Process already active, queueing command for queue: $id" );
        my $queue = { logfile    => $logfile,
                      pidfile    => $pidfile,
                      command    => $command,
                      id         => $id,
                      lastupdate => time,
                      message    => $message,
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

    $self->logger->info( "Forking new process for: $process->{id}" );
    $self->logger->debug( "TRYING FORK: ", YAML::Dump $process );

    my $message = $process->{message} || {};

    if ( my $pid = fork() ) {
        $self->logger->info( "Fork succeeded, creating pidfile: $process->{pidfile}" );

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

    # wu - ugly bug fix - when closing STDIN, it becomes free and
    # may later get reused when calling open (resulting in error
    # 'Filehandle STDIN reopened as $fh only for output'). :/ So
    # instead of closing, just re-open to /dev/null.
    open STDIN, '<', '/dev/null'       or die "$!";

    if ( -r $process->{logfile} ) {
        unlink $process->{logfile};
    }

    open STDOUT, '>>', $process->{logfile} or die "Can't write stdout to $process->{logfile}: $!";
    STDOUT->autoflush(1);

    open STDERR, '>>', $process->{logfile} or die "Can't write stderr to $process->{logfile}: $!";
    STDERR->autoflush(1);

    setsid or die "Can't start a new session: $!";

    $self->logger->trace( "Launching process: $process->{id}: $process->{command}" );

    # run command capturing output
    my $pid = open my $run, "-|", "$process->{command} 2>&1" or die "Unable to execute $process->{command}: $!";

    while ( my $line = <$run> ) {
        chomp $line;
        print "$line\n";
    }
    close $run;

    $child->{message}  = $message;
    $child->{id}       = $process->{id};
    $child->{status}   = 0;
    $child->{signal}   = 0;
    $child->{pidfile}  = $process->{pidfile};
    $child->{logdir}   = $self->logdir;
    $child->{childpid} = $pid;

    $SIG{'INT'} = 'INT_handler';

    # check exit status
    my $status = 0;
    my $signal = 0;

    unless ( $? eq 0 ) {
        $child->{status} = $? >> 8;
        $child->{signal} = $? & 127;
        $self->logger->error( "Error running command:$process->{id}\n\tstatus=$child->{status}\n\tsignal=$child->{signal}" );
    }

    $self->logger->trace( "Process exited: $process->{id}" );

    unlink( $process->{pidfile} );

    child_done();
}

sub INT_handler {
    $child->{signal} = 1;
}

sub child_done {
    my $id = $child->{id};

    close STDOUT;
    close STDERR;

    my $directory  = $child->{logdir};
    my $statusfile = "$directory/$child->{id}.status";

    YAML::XS::DumpFile( $statusfile,
                        { command_status => $child->{status},
                          command_signal => $child->{signal},
                          message        => $child->{message},
                      } );

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
        $self->logger->debug( "Process $id responded to kill 0: $pid" );
        return $pid;
    }

    $self->logger->info( "Pidfile exists but pid not active: $pid" );
    unlink( $pidfile );

    return;
}

1;
