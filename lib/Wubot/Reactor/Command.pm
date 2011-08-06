package Wubot::Reactor::Command;
use Moose;

# VERSION

use FileHandle;
use File::Path;
use Log::Log4perl;
use POSIX qw(strftime setsid :sys_wait_h);
use Term::ANSIColor;
use YAML::XS;

use Wubot::SQLite;

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

has 'queuedb'   => ( is       => 'ro',
                     isa      => 'Str',
                     lazy     => 1,
                     default  => sub {
                         my $self = shift;
                         return join( "/", $ENV{HOME}, "wubot", "sqlite", "command.sql" );
                     },
                 );

has 'sqlite'    => ( is       => 'ro',
                     isa      => 'Wubot::SQLite',
                     lazy     => 1,
                     default  => sub {
                         my $self = shift;
                         $self->logger->warn( "Command: connecting to sqlite db: ", $self->queuedb );
                         return Wubot::SQLite->new( { file => $self->queuedb } );
                     },
               );

my $is_null = "IS NULL";
my $is_not_null = "IS NOT NULL";

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
    elsif ( $config->{command_array} ) {
        my @entries;
        for my $entry ( @{ $config->{command_array} } ) {
            if ( $entry =~ m|^\{\$([\w\d\-]+)\}| ) {
                if ( $message->{ $1 } ) { $entry = $message->{ $1 } };
            }
            $entry =~ s|\'||;
            #$entry = shell_quote( $entry );
            push @entries, "'$entry'";
        }
        $command = join( " ", @entries );
    }
    else {
        $self->logger->error( "Command reactor error: no command or command_field specified in config" );
        return $message;
    }

    if ( $config->{command_noresults} ) {
        $message->{command_noresults} = 1;
    }

    if ( $config->{fork} ) {
        return $self->enqueue( $command, $message, $config );
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
        $self->logger->error( "Error running command: $command\n\tstatus=$status\n\tsignal=$signal\nOUTPUT:\n$output" );
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

        $self->logger->debug( "Command: collecting finish process info for $id" );

        my $logfile = "$directory/$id.log";

        my $output = "";
        if ( -r $logfile ) {
            $self->logger->debug( "Command: Reading command output from logfile: $logfile" );
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
        $message->{command_status} = 0;
        $message->{command_signal} = 0;

        my ( $status ) = $self->sqlite->select( { tablename => 'command_queue',
                                                  where     => { queueid => $id, seen => \$is_null, started => \$is_not_null },
                                                  order     => 'id',
                                              } );

        if ( $status ) {
            # deserialize the message data
            if ( $status->{message} ) {
                $status->{message} = Load $status->{message};
            }
            else {
                $self->logger->error( "ERROR: queue entry has no message", YAML::Dump $status );
            }

            $message->{command_status} = $status->{status};
            $message->{command_signal} = $status->{signal};
            $message->{command_queue}  = $id;

            for my $key ( keys %{ $status->{message} } ) {
                unless ( exists $message->{$key} ) {
                    $message->{$key} = $status->{message}->{$key};
                }
            }
            delete $message->{message};

            $self->sqlite->update( 'command_queue',
                                   { seen     => time,
                                 },
                                   { id       => $status->{id} },
                               );

        }
        else {
            $self->logger->error( "ERROR: no status information found about finished process!" );
        }

        if ( $message->{command_status} || $message->{command_signal} ) {
            my $subject = "Command failed: $id";
            if ( $message->{command_status} ) {
                $subject .= " status=$message->{command_status}";
            }
            if ( $message->{command_signal} ) {
                $subject .= " signal=$message->{command_signal}";
            }
            if ( $message->{command_name} ) {
                $subject .= " => $message->{command_name}";
            }
            $message->{subject} = $subject;
            $self->logger->error( $subject );
            $self->logger->error( $output );
        }
        else {
            my $subject = "Command succeeded: $id";
            if ( $message->{command_name} ) {
                $subject .= " => $message->{command_name}";
            }
            $message->{subject} = $subject;
            if ( $message->{command_noresults} ) {
                $self->logger->debug( $subject );
            }
            else {
                $self->logger->info( $subject );
            }
        }


        $self->logger->debug( "Command: collected information about process $id" );

        unless ( $message->{command_noresults} ) {
            push @messages, $message;
        }

        # TODO: hole here where message could be lost after the log is deleted!

        $self->logger->debug( "Unlinking logfile: $logfile" );
        unlink( $logfile );
    }

    closedir( $dir_h );

    $self->logger->debug( "Searching for processes in queue to be started" );

    my @queues;
    eval {                          # try
        @queues = $self->sqlite->select( { tablename => 'command_queue',
                                           fields    => 'DISTINCT queueid'
                                       } );
        1;
    } or do {                       # catch
        $self->logger->debug( "Command: No queue data found" );
        $self->logger->trace( $@ );
    };

  QUEUE:
    for my $queue ( @queues ) {

        my $id = $queue->{queueid};

        $self->logger->debug( "Checking queue: $queue->{queueid}" );

        my $pidfile = join( "/", $self->logdir, "$id.pid" );
        my $logfile = join( "/", $self->logdir, "$id.log" );

         if ( -r $pidfile ) {
             $self->logger->debug( "Previous process still running: $pidfile" );
             next QUEUE;
         }
         if ( -r $logfile ) {
             $self->logger->debug( "Previous logfile not yet cleaned up: $logfile" );
             next QUEUE;
         }

        my ( $entry ) = $self->sqlite->select( { tablename => 'command_queue',
                                                 where     => { queueid => $id, started => \$is_null, seen => \$is_null },
                                                 order     => 'id',
                                             },
                                           );

        if ( $entry ) {

            $entry->{sqlid} = $entry->{id};
            $entry->{id} = $entry->{queueid};

            # de-serialize the original message data
            if ( $entry->{message} ) {
                $entry->{message} = Load $entry->{message};
            }
            else {
                $self->logger->error( "Warning, no serialized message data for command: queue=$id id=$entry->{sqlid}" );
            }

            if ( my $results = $self->try_fork( $entry ) ) {

                # TODO: react to message
                #push @messages, { subject => "forked process for queue $id" };

            }
        }

    }

    return unless scalar @messages;

    return \@messages;
}

sub enqueue {
    my ( $self, $command, $message, $config ) = @_;

    my $id = $config->{fork};

    unless ( -d $self->logdir ) {
        mkpath( $self->logdir );
    }

    my $logfile = join( "/", $self->logdir, "$id.log" );
    my $pidfile = join( "/", $self->logdir, "$id.pid" );

    my $sqlid = $self->sqlite->insert( 'command_queue',
                                       { command    => $command,
                                         pidfile    => $pidfile,
                                         logfile    => $logfile,
                                         queueid    => $id,
                                         lastupdate => time,
                                         message    => Dump( $message ),
                                     },
                                   );

    $self->logger->debug( "Command: queueing for: $id [$sqlid]" );

    $message->{sqlid}          = $sqlid;
    $message->{command_queued} = 1;
    return $message;
}

sub try_fork {
    my ( $self, $process ) = @_;

    $self->logger->debug( "Forking new process for: $process->{id}" );
    $self->logger->debug( "Command: $process->{command}" );

    my $message = $process->{message} || {};

    if ( my $pid = fork() ) {
        $self->logger->debug( "Fork succeeded, creating pidfile: $process->{pidfile} [$process->{sqlid}]" );

        open(my $fh, ">", $process->{pidfile})
            or die "Couldn't open $process->{pidfile} for writing: $!\n";
        print $fh $pid;
        close $fh or die "Error closing file: $!\n";

        $self->sqlite->update( 'command_queue',
                               { logfile  => $process->{logfile},
                                 logdir   => $self->{logdir},
                                 pidfile  => $process->{pidfile},
                                 started  => time,
                                 pid      => $pid,
                             },
                               { id       => $process->{sqlid} },
                           );


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

    #setpgrp or die "Can't start a new session: $!";
    setsid or die "Can't start a new session: $!";

    $self->logger->trace( "Launching process: $process->{id}: $process->{command}" );

    # run command capturing output
    my $pid = open my $run, "-|", "$process->{command} 2>&1" or die "Unable to execute $process->{command}: $!";

    $self->sqlite->update( 'command_queue',
                           { childpid => $pid,
                             logfile  => $process->{logfile},
                             logdir   => $self->{logdir},
                             pidfile  => $process->{pidfile},
                         },
                           { id       => $process->{sqlid} },
                       );

    while ( my $line = <$run> ) {
        chomp $line;
        print "$line\n";
    }
    close $run;

    # check exit status
    my $status = 0;
    my $signal = 0;

    unless ( $? eq 0 ) {
        $status = $? >> 8;
        $signal = $? & 127;
        warn "Error running command: $process->{id}: status=$status signal=$signal\n";
    }

    $self->logger->trace( "Process exited: $process->{id}" );

    unlink( $process->{pidfile} );

    $self->sqlite->update( 'command_queue',
                           { status   => $status,
                             signal   => $signal,
                         },
                           { id       => $process->{sqlid} },
                       );

    close STDOUT;
    close STDERR;

    exit;
}

sub check_process {
    my ( $self, $id ) = @_;

    my $pidfile = join( "/", $self->logdir, "$id.pid" );

    unless ( -r $pidfile ) {
        $self->logger->debug( "Pidfile not found: $pidfile" );
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

    $self->logger->debug( "Pidfile exists but pid not active: $pid" );
    unlink( $pidfile );

    return;
}

1;
