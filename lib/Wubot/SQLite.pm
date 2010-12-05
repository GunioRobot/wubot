package Wubot::SQLite;
use Moose;

use DBI;
use DBD::SQLite;

has 'file' => ( is       => 'ro',
                isa      => 'Str',
                required => 1,
            );

has 'dbh'  => ( is       => 'rw',
                isa      => 'DBI::db',
                lazy     => 1,
                default  => sub {
                    my ( $self ) = @_;
                    return $self->connect();
                },
            );

sub create_table {
    my ( $self, $table, $schema_h ) = @_;

    unless ( $table ) {
        die "Error: table not specified";
    }

    unless ( $schema_h ) {
        die( "Error: schema not specified" );
    }

    my $command = "CREATE TABLE $table (\n";

    my @lines;
    for my $key ( keys %{ $schema_h } ) {
        my $type = $schema_h->{$key};
        push @lines, "\t$key $type";
    }
    $command .= join ",\n", @lines;

    $command .= "\n);";

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

sub insert {
    my ( $self, $table, $entry, $schema_h ) = @_;

    unless ( $entry && ref $entry eq "HASH" ) {
        die "ERROR: insert: entry undef or not a hashref";
    }
    unless ( $table && $table =~ m|^\w+$| ) {
        die "ERROR: insert: table name does not look valid"
    }
    unless ( $schema_h && ref $schema_h eq "HASH" ) {
        die "ERROR: no schema specified to insert command!";
    }

    my ( $command, @keys ) = $self->get_insert_command( $table, $schema_h );

    my $sth1 = $self->get_prepared( $table, $schema_h, $command );

    my @insert = map { defined $entry->{$_} ? $entry->{$_} : "" } @keys;

    $sth1->execute( @insert );

    return $self->dbh->last_insert_id( "", "", $table, "");
}

sub query {
    my ( $self, $statement, $callback ) = @_;

    my $sth = $self->dbh->prepare($statement) or die "Can't prepare $statement\n";
    my $rv  = $sth->execute or die "can't execute the query: $statement\n";

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
        die "ERROR: delete: invalid table name";
    }
    unless ( $conditions && ref $conditions eq "HASH" ) {
        die "ERROR: delete: conditions is not a hash ref"
    }

    my $delete = "DELETE FROM $table WHERE ";

    my @conditions;
    for my $key ( keys %{ $conditions } ) {
        push @conditions, "$key = '$conditions->{$key}'";
    }

    $delete .= join( " AND ", @conditions );

    $self->dbh->do( $delete );
}


sub get_insert_command {
    my ( $self, $table, $schema_h ) = @_;

    # temporary schema hash, remove the id
    my $insert_schema_h = { %{ $schema_h } };
    delete $insert_schema_h->{id};

    # create the insert statement
    my @keys = sort keys %{ $insert_schema_h };
    my $insert = join( ",", @keys );

    my $values = "?," x $#keys . "?";
    my $command = qq{ INSERT INTO $table ( $insert )
                       VALUES ($values)
     };

    return $command, @keys;
}


sub get_prepared {
    my ( $self, $table, $schema, $command ) = @_;

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
                print "Creating missing table: $table\n";
                $self->create_table( $table, $schema );
                $self->{tables}->{$table} = 1;
                next RETRY;
            } elsif ( $error =~ m/(?:has no column named|no such column\:) (\S+)/ ) {
                my $column = $1;

                unless ( $column ) { die "ERROR: failed to capture a column name!" }

                print "Adding missing column: $column\n";

                if ( $schema->{$column} ) {
                    $self->add_column( $table, $column, $schema->{$column} );
                    next RETRY;
                } else {
                    die "Missing column not defined in schema: $column";
                }
            } else {
                die "Unhandled error: $error";
            }

        };

        return $sth1;
    };

    die "ERROR: unable to prepare statement, exceeded maximum retry limit";
}

sub add_column {
    my ( $self, $table, $column, $type ) = @_;
    my $command = "ALTER TABLE $table ADD COLUMN $column $type";
    $self->dbh->do( $command );
}


sub connect {
    my ( $self ) = @_;

    my $datafile = $self->file;
    print "Opening sqlite file: $datafile\n";

    my $dbh = DBI->connect(
        "dbi:SQLite:$datafile", "", "",
        {
            AutoCommit => 1,
            RaiseError => 1,
        }
    ) or die "Unable to create database handle: $!";

    return $dbh;
}

sub disconnect {
    my ( $self ) = @_;

    $self->dbh->disconnect;
}


1;
