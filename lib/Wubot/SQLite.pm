package Wubot::SQLite;
use Moose;

# VERSION

use Capture::Tiny;
use DBI;
use DBD::SQLite;
use Devel::StackTrace;
use FindBin;
use Log::Log4perl;
use SQL::Abstract;
use YAML;

# only initialize one connection to each database handle
my %sql_handles;

# don't continually reload schemas
my %schemas;

has 'file'         => ( is       => 'ro',
                        isa      => 'Str',
                        required => 1,
                    );

has 'dbh'          => ( is       => 'rw',
                        isa      => 'DBI::db',
                        lazy     => 1,
                        default  => sub {
                            my ( $self ) = @_;
                            return $self->connect();
                        },
                    );

has 'sql_abstract' => ( is       => 'ro',
                        isa      => "SQL::Abstract",
                        lazy     => 1,
                        default  => sub {
                            return SQL::Abstract->new;
                        },
                    );

has 'schema_dir'   => ( is       => 'ro',
                        isa      => 'Str',
                        lazy     => 1,
                        default  => sub {
                            my $self = shift;
                            my $schema_dir = join( "/", $ENV{HOME}, "wubot", "schemas" );
                            $self->logger->debug( "schema directory: $schema_dir" );
                            return $schema_dir;
                        },
                    );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );



sub create_table {
    my ( $self, $table, $schema_h ) = @_;

    unless ( $table ) {
        $self->logger->logcroak( "Error: table not specified" );
    }
    $schema_h = $self->check_schema( $table, $schema_h );

    my $command = "CREATE TABLE $table (\n";

    my @lines;
    for my $key ( keys %{ $schema_h } ) {
        next if $key eq "constraints";
        my $type = $schema_h->{$key};
        push @lines, "\t$key $type";
    }

    if ( $schema_h->{constraints} ) {
        for my $constraint ( @{ $schema_h->{constraints} } ) {
            push @lines, "\t$constraint";
        }
    }
    $command .= join ",\n", @lines;

    $command .= "\n);";

    $self->logger->trace( $command );

    $self->dbh->do( $command );
}

sub get_tables {
    my ( $self, $table ) = @_;

    my $sth = $self->dbh->table_info(undef, undef, $table, 'TABLE' );

    my @tables;

    while ( my $entry = $sth->fetchrow_hashref ) {
        next if $entry->{TABLE_NAME} eq "sqlite_sequence";
        push @tables, $entry->{TABLE_NAME};
    }

    return @tables;
}

sub check_schema {
    my ( $self, $table, $schema_h, $failok ) = @_;

    unless ( $schema_h ) {
        unless ( $self->get_schema( $table ) ) {
            if ( $failok ) {
                $self->logger->debug( "no schema specified, and global schema not found for table: $table" );
                return;
            }
            else {
                $self->logger->debug( Devel::StackTrace->new->as_string );
                $self->logger->logdie( "FATAL: no schema specified, and global schema not found for table: $table" );
            }
        }
        $schema_h = $self->get_schema( $table );
    }

    unless ( $schema_h ) {
        $self->logger->logcroak( "Error: no schema specified or found for table: $table" );
    }

    unless ( ref $schema_h eq "HASH" ) {
        $self->logger->logcroak( "ERROR: schema for table $table is invalid: not a hash ref" );
    }

    return $schema_h;
}

sub insert {
    my ( $self, $table, $entry, $schema_h ) = @_;

    unless ( $entry && ref $entry eq "HASH" ) {
        $self->logger->logcroak( "ERROR: insert: entry undef or not a hashref" );
    }
    unless ( $table && $table =~ m|^\w+$| ) {
        $self->logger->logcroak( "ERROR: insert: table name does not look valid" );
    }
    $schema_h = $self->check_schema( $table, $schema_h );

    my $insert;
    for my $field ( keys %{ $schema_h } ) {
        next if $field eq "constraints";
        next if $field eq "id";
        $insert->{ $field } = $entry->{ $field };
    }

    my( $command, @bind ) = $self->sql_abstract->insert( $table, $insert );

    my $sth1 = $self->get_prepared( $table, $schema_h, $command );

    eval {                          # try
        my ($stdout, $stderr) = Capture::Tiny::capture {
            $sth1->execute( @bind );
        };

        if ( $stdout ) { $self->logger->warn( $stdout ) }
        if ( $stderr ) { $self->logger->warn( $stderr ) }

        1;
    } or do {                       # catch
        return;
    };

    return $self->dbh->last_insert_id( "", "", $table, "");
}

sub update {
    my ( $self, $table, $update, $where, $schema_h ) = @_;

    $schema_h = $self->check_schema( $table, $schema_h );

    my $insert;
    for my $field ( keys %{ $schema_h } ) {
        next if $field eq "constraints";
        next if $field eq "id";
        next unless exists $update->{ $field };
        $insert->{ $field } = $update->{ $field };
    }

    my( $command, @bind ) = $self->sql_abstract->update( $table, $insert, $where );

    my $sth1 = $self->get_prepared( $table, $schema_h, $command );

    eval {                          # try
        my ($stdout, $stderr) = Capture::Tiny::capture {
            $sth1->execute( @bind );
        };

        if ( $stdout ) { $self->logger->warn( $stdout ) }
        if ( $stderr ) { $self->logger->warn( $stderr ) }

        1;
    } or do {                       # catch
        return;
    };

    return 1;
}

sub insert_or_update {
    my ( $self, $table, $update, $where, $schema_h ) = @_;

    $schema_h = $self->check_schema( $table, $schema_h );

    my $count;
    # wrap select() in an eval, this could fail, e.g. if the table does not already exist
    eval {
        $self->select( { tablename => $table, where => $where, callback => sub { $count++ }, schema => $schema_h } );
    };

    if ( $count ) {
        $self->logger->debug( "updating $table" );
        return $self->update( $table, $update, $where, $schema_h );
    }

    $self->logger->debug( "inserting into $table" );
    return $self->insert( $table, $update, $schema_h );

    return 1;
}

sub select {
    my ( $self, $options ) = @_;

    my $tablename = $options->{tablename};
    unless ( $tablename ) {
        $self->logger->logcroak( "ERROR: select called but no tablename provided" );
    }

    # if ( $self->logger->is_trace() ) {
    #     my $log_text = YAML::Dump $options;
    #     $self->logger->trace( "SQL Select: $log_text" );
    # }

    my $fields    = $options->{fields}     || '*';
    my $where     = $options->{where};
    my $order     = $options->{order};
    my $limit     = $options->{limit};

    my $callback  = $options->{callback};

    my( $statement, @bind ) = $self->sql_abstract->select( $tablename, $fields, $where, $order );

    if ( $limit ) { $statement .= " LIMIT $limit" }

    #$self->logger->debug( "SQLITE: $statement", YAML::Dump @bind );

    my $schema_h = $self->check_schema( $tablename, $options->{schema}, 1 );

    my $sth = $self->get_prepared( $tablename, $schema_h, $statement );

    my $rv;
    eval {
        $rv = $sth->execute(@bind);
        1;
    } or do {
        $self->logger->logcroak( "can't execute the query: $statement: $@" );
    };

    my @entries;

    while ( my $entry = $sth->fetchrow_hashref ) {

        if ( $callback ) {
            $callback->( $entry );
        }
        else {
            push @entries, $entry;
        }
    }

    if ( $callback ) {
        return 1;
    }
    else {
        return @entries;
    }
}

sub query {
    my ( $self, $statement, $callback ) = @_;

    my ( $sth, $rv );
    my ($stdout, $stderr) = Capture::Tiny::capture {
        $sth = $self->dbh->prepare($statement) or $self->logger->logcroak( "Can't prepare $statement" );
        $rv  = $sth->execute or $self->logger->logcroak( "can't execute the query: $statement" );
    };

    if ( $stdout ) { $self->logger->warn( $stdout ) }
    if ( $stderr ) { $self->logger->warn( $stderr ) }

    my @return;

    while ( my $entry = $sth->fetchrow_hashref ) {
        if ( $callback ) {
            $callback->( $entry );
        }
        else {
            push @return, $entry;
        }
    }

    return @return;
}

sub delete {
    my ( $self, $table, $conditions ) = @_;

    unless ( $table && $table =~ m|^\w+$| ) {
        $self->logger->logcroak( "ERROR: delete: invalid table name" );
    }
    unless ( $conditions && ref $conditions eq "HASH" ) {
        $self->logger->logcroak( "ERROR: delete: conditions is not a hash ref" );
    }

    my( $statement, @bind ) = $self->sql_abstract->delete( $table, $conditions );

    $self->logger->trace( join( ", ", $statement, @bind ) );

    my $sth = $self->dbh->prepare($statement) or confess "Can't prepare $statement\n";

    my $rv;
    eval {
        $sth->execute(@bind);
        1;
    } or do {
        $self->logger->logcroak( "can't execute the query: $statement: $@" );
    };

}


sub get_prepared {
    my ( $self, $table, $schema, $command ) = @_;

    $self->logger->trace( $command );

    my $sth1;

    # make sure dbh has been lazy loaded before we try to use it below
    # inside Capture::Tiny
    $self->dbh;

  RETRY:
    for my $retry ( 0 .. 10 ) {
        eval {                          # try

            my ($stdout, $stderr) = Capture::Tiny::capture {
                $sth1 = $self->dbh->prepare( $command );
            };

            if ( $stdout ) { $self->logger->warn( $stdout ) }
            if ( $stderr ) { $self->logger->warn( $stderr ) }

            1;
        } or do {                       # catch
            my $error = $@;

            # if the table doesn't already exist, create it
            if ( $error =~ m/no such table/ ) {
                $self->logger->warn( "Creating missing table: $table" );
                $self->create_table( $table, $schema );
                $self->{tables}->{$table} = 1;
                next RETRY;
            } elsif ( $error =~ m/(?:has no column named|no such column\:) (\S+)/ ) {
                my $column = $1;

                unless ( $column ) { $self->logger->logcroak( "ERROR: failed to capture a column name!"  ) }

                $self->logger->warn( "Adding missing column: $column" );

                if ( $schema->{$column} ) {
                    $self->add_column( $table, $column, $schema->{$column} );
                    next RETRY;
                } else {
                    $self->logger->logcroak( "Missing column not defined in schema: $column" );
                }
            } else {
                $self->logger->logcroak( "Unhandled error: $error" );
            }

        };

        return $sth1;
    };

    $self->logger->logcroak( "ERROR: unable to prepare statement, exceeded maximum retry limit" );
}

sub add_column {
    my ( $self, $table, $column, $type ) = @_;
    my $command = "ALTER TABLE $table ADD COLUMN $column $type";
    $self->dbh->do( $command );
}

sub connect {
    my ( $self ) = @_;

    my $datafile = $self->file;

    if ( $sql_handles{ $datafile } ) {
        return $sql_handles{ $datafile };
    }

    $self->logger->warn( "Opening sqlite file: $datafile" );

    my $dbh = DBI->connect(
        "dbi:SQLite:$datafile", "", "",
        {
            AutoCommit => 1,
            RaiseError => 1,
        }
    ) or $self->logger->logcroak( "Unable to create database handle: $!" );

    $sql_handles{ $datafile } = $dbh;

    return $dbh;
}

sub disconnect {
    my ( $self ) = @_;

    $self->dbh->disconnect;
}

sub get_schema {
    my ( $self, $table ) = @_;

    unless ( $table ) {
        $self->logger->logconfess( "ERROR: get_schema called but no table specified" );
    }
    unless ( $table =~ m|^[\w\d\_]+$| ) {
        $self->logger->logconfess( "ERROR: table name contains invalid characters: $table" );
    }

    my $schema_file = join( "/", $self->schema_dir, "$table.yaml" );
    $self->logger->debug( "looking for schema file: $schema_file" );

    unless ( -r $schema_file ) {
        $self->logger->debug( "schema file not found: $schema_file" );
        return;
    }

    my $mtime = ( stat $schema_file )[9];
    my $schema = {};

    if ( $schemas{$table} ) {

        if ( $mtime > $schemas{$table}->{mtime} ) {

            # file updated since last load
            $self->logger->warn( "Re-loading $table schema: $schema_file" );
            $schema = YAML::LoadFile( $schema_file );
        }
        else {
            # no updates, return from memory
            return $schemas{$table}->{table};
        }

    }
    else {

        # hasn't yet been loaded from memory
        $self->logger->info( "Loading $table schema: $schema_file" );
        $schema = YAML::LoadFile( $schema_file );

    }

    $schemas{$table}->{table} = $schema;
    $schemas{$table}->{mtime} = $mtime;

    return $schema;
}

1;
