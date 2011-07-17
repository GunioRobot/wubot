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

has 'qschema'   => ( is       => 'ro',
                     isa      => 'HashRef',
                     lazy     => 1,
                     default  => sub {
                         return { command    => 'text',
                                  message    => 'text',
                                  queueid    => 'varchar(32)',
                                  started    => 'int',
                                  pid        => 'int',
                                  status     => 'int',
                                  signal     => 'int',
                                  pidfile    => 'varchar(128)',
                                  logfile    => 'varchar(128)',
                                  childpid   => 'int',
                                  lastupdate => 'int',
                                  output     => 'text',
                                  id         => 'INTEGER PRIMARY KEY AUTOINCREMENT',
                                  seen       => 'int',
                              };
                     },
                 );

has 'sqlite'    => ( is       => 'ro',
                     isa      => 'Wubot::SQLite',
                     lazy     => 1,
                     default  => sub {
                         my $self = shift;
                         $self->logger->error( "CREATING sqlite db with file: ", $self->queuedb );
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
            $self->logger->info( "Command: Reading command output from logfile: $logfile" );
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

        my ( $status ) = $self->sqlite->select( { tablename => 'queue',
                                                  where     => { queueid => $id, seen => \$is_null, started => \$is_not_null },
                                                  order     => 'lastupdate DESC',
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

            for my $key ( keys %{ $status->{message} } ) {
                unless ( $message->{$key} ) {
                    $message->{$key} = $status->{message}->{$key};
                }
            }
            delete $message->{message};

            $self->sqlite->update( 'queue',
                                   { seen     => time,
                                 },
                                   { id       => $status->{id} },
                                   $self->qschema,
                               );

        }
        else {
            $self->logger->error( "ERROR: no status information found about finished process!" );
        }



        if ( $message->{status} || $message->{signal} ) {
            $message->{subject} = "Command failed: $id [$message->{status}:$message->{signal}]";
        }
        else {
            $message->{subject} = "Command succeeded: $id";
        }

        $self->logger->info( "Command: collected information about process $id" );
        push @messages, $message;

        # TODO: hole here where message could be lost after the log is deleted!

        $self->logger->info( "Unlinking logfile: $logfile" );
        unlink( $logfile );
    }

    closedir( $dir_h );

    $self->logger->debug( "Searching for processes in queue to be started" );

    my @queues;
    eval {                          # try
        @queues = $self->sqlite->select( { tablename => 'queue',
                                           column    => 'DISTINCT queueid'
                                       } );
        1;
    } or do {                       # catch
        $self->logger->debug( "Command: No queue data found" );
        $self->logger->trace( $@ );
    };

  QUEUE:
    for my $queue ( @queues ) {

        my $id = $queue->{queueid};

        $self->logger->info( "Checking queue: $queue->{queueid}" );

        my $pidfile = join( "/", $self->logdir, "$id.pid" );
        my $logfile = join( "/", $self->logdir, "$id.log" );

         if ( -r $pidfile ) {
             $self->logger->debug( "Previous process still running: $pidfile" );
             last QUEUE;
         }
         if ( -r $logfile ) {
             $self->logger->debug( "Previous logfile not yet cleaned up: $logfile" );
             last QUEUE;
         }

        my $is_null = "IS NULL";
        my ( $entry ) = $self->sqlite->select( { tablename => 'queue',
                                                 where     => { queueid => $id, started => \$is_null, seen => \$is_null },
                                                 order     => 'lastupdate DESC',
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

    my $sqlid = $self->sqlite->insert( 'queue',
                                       { command    => $command,
                                         pidfile    => $pidfile,
                                         logfile    => $logfile,
                                         queueid    => $id,
                                         lastupdate => time,
                                         message    => Dump( $message ),
                                     },
                                       $self->qschema,
                                   );

    if ( $self->check_process( $id ) ) {

        $self->logger->info( "Process already active, queueing command for queue: $id" );

        $message->{sqlid}          = $sqlid;
        $message->{command_queued} = 1;
        return $message;
    }

    return $self->try_fork( { id      => $id,
                              message => $message,
                              command => $command,
                              logfile => $logfile,
                              pidfile => $pidfile,
                              sqlid   => $sqlid,
                          } );
}

sub try_fork {
    my ( $self, $process ) = @_;

    $self->logger->info( "Forking new process for: $process->{id}" );
    $self->logger->debug( "TRYING FORK: ", YAML::Dump $process );

    my $message = $process->{message} || {};

    if ( my $pid = fork() ) {
        $self->logger->info( "Fork succeeded, creating pidfile: $process->{pidfile} [$process->{sqlid}]" );

        open(my $fh, ">", $process->{pidfile})
            or die "Couldn't open $process->{pidfile} for writing: $!\n";
        print $fh $pid;
        close $fh or die "Error closing file: $!\n";

        $self->sqlite->update( 'queue',
                               { logfile  => $process->{logfile},
                                 logdir   => $self->{logdir},
                                 pidfile  => $process->{pidfile},
                                 started  => time,
                                 pid      => $pid,
                             },
                               { id       => $process->{sqlid} },
                               $self->qschema,
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

    setsid or die "Can't start a new session: $!";

    $self->logger->trace( "Launching process: $process->{id}: $process->{command}" );

    # run command capturing output
    my $pid = open my $run, "-|", "$process->{command} 2>&1" or die "Unable to execute $process->{command}: $!";

    $self->sqlite->update( 'queue',
                           { childpid => $pid,
                             logfile  => $process->{logfile},
                             logdir   => $self->{logdir},
                             pidfile  => $process->{pidfile},
                         },
                           { id       => $process->{sqlid} },
                           $self->qschema,
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
        $self->logger->error( "Error running command:$process->{id}\n\tstatus=$status\n\tsignal=$signal" );
    }

    $self->logger->trace( "Process exited: $process->{id}" );

    unlink( $process->{pidfile} );

    $self->sqlite->update( 'queue',
                           { status   => $status,
                             signal   => $signal,
                         },
                           { id       => $process->{sqlid} },
                           $self->qschema,
                       );

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
        $self->logger->debug( "Process $id responded to kill 0: $pid" );
        return $pid;
    }

    $self->logger->info( "Pidfile exists but pid not active: $pid" );
    unlink( $pidfile );

    return;
}

1;
