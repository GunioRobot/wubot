package Wubot::SQLite;
use Moose;

# VERSION

use DBI;
use DBD::SQLite;
use FindBin;
use Log::Log4perl;
use SQL::Abstract;
use YAML;

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

has 'schema_file' => ( is       => 'ro',
                        isa      => 'Str',
                        lazy     => 1,
                        default  => sub {
                            my $self = shift;
                            my $schema_file = join( "/", $ENV{HOME}, "wubot", "config", "schemas.yaml" );
                            $self->logger->debug( "schema file: $schema_file" );
                            return $schema_file;
                        },
                    );

has 'global_schema_file' => ( is       => 'ro',
                              isa      => 'Str',
                              lazy     => 1,
                              default  => sub {
                                  my $self = shift;
                                  my $schema_file = join( "/", "$FindBin::Bin/../conf", "schemas.yaml" );
                                  $self->logger->debug( "schema file: $schema_file" );
                                  return $schema_file;
                              },
                          );

has 'sql_schemas'  => ( is       => 'ro',
                        isa      => 'HashRef',
                        lazy     => 1,
                        default  => sub {
                            my $self = shift;
                            return $self->read_schemas();
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

    $self->logger->debug( $command );

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
        unless ( $self->sql_schemas->{ $table } ) {
            if ( $failok ) {
                $self->logger->debug( "WARNING: no schema specified, and global schema not found for table: $table" );
                return;
            }
            else {
                $self->logger->logconfess( "WARNING: no schema specified, and global schema not found for table: $table" );
            }
        }
        $schema_h = $self->sql_schemas->{ $table };
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
        $insert->{ $field } = $entry->{ $field };
    }

    my( $command, @bind ) = $self->sql_abstract->insert( $table, $insert );

    my $sth1 = $self->get_prepared( $table, $schema_h, $command );

    eval {                          # try
        $sth1->execute( @bind );
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
        next unless exists $update->{ $field };
        $insert->{ $field } = $update->{ $field };
    }

    my( $command, @bind ) = $self->sql_abstract->update( $table, $insert, $where );

    my $sth1 = $self->get_prepared( $table, $schema_h, $command );

    eval {                          # try
        $sth1->execute( @bind );
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
        $self->select( { tablename => $table, where => $where, callback => sub { $count++ } } );
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

    my $schema_h = $self->check_schema( $tablename, undef, 1 );

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

    my $sth = $self->dbh->prepare($statement) or $self->logger->logcroak( "Can't prepare $statement" );
    my $rv  = $sth->execute or $self->logger->logcroak( "can't execute the query: $statement" );

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

  RETRY:
    for my $retry ( 0 .. 10 ) {
        eval {                          # try
            $sth1 = $self->dbh->prepare( $command );
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
    $self->logger->warn( "Opening sqlite file: $datafile" );

    my $dbh = DBI->connect(
        "dbi:SQLite:$datafile", "", "",
        {
            AutoCommit => 1,
            RaiseError => 1,
        }
    ) or $self->logger->logcroak( "Unable to create database handle: $!" );

    return $dbh;
}

sub disconnect {
    my ( $self ) = @_;

    $self->dbh->disconnect;
}

sub read_schemas {
    my ( $self ) = @_;

    my $schemas = {};

    my $user_schema_file = $self->schema_file;
    if ( -r $user_schema_file ) {
        $self->logger->info( "Loading schema file: $user_schema_file" );
        my $user_schemas = YAML::LoadFile( $user_schema_file );
        for my $table ( keys %{ $user_schemas } ) {
            $self->logger->info( "Adding user schema for table: $table" );
            $schemas->{ $table } = $user_schemas->{$table};
        }
    } else {
        $self->logger->warn( "user schema file not found: $user_schema_file" );
    }

    my $global_schema_file = $self->global_schema_file;
    if ( -r $global_schema_file ) {
        $self->logger->info( "Loading global schema file: $global_schema_file" );
        my $global_schemas = YAML::LoadFile( $global_schema_file );
        for my $table ( keys %{ $global_schemas } ) {
            next if $schemas->{ $table };
            $self->logger->info( "Adding global schema for table: $table" );
            $schemas->{ $table } = $global_schemas->{$table};
        }
    } else {
        $self->logger->warn( "global schema file not found: $global_schema_file" );
    }

    return $schemas;
}

1;
