#!/perl
use strict;

use Capture::Tiny;
use File::Temp qw/ tempdir /;
use Log::Log4perl qw(:easy);
use Test::Exception;
use Test::More 'no_plan';
use YAML;

use Wubot::Logger;
use Wubot::SQLite;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

my $sqldb = "$tempdir/test.sql";

ok( my $sql = Wubot::SQLite->new( { file               => $sqldb,
                                } ),
    "Creating new Wubot::SQLite object"
);

ok( $sql->dbh,
    "Forcing dbh connection to lazy load"
);

ok( -r $sqldb,
    "Checking that sql db was created: $sqldb"
);

{
    my $table = "test_table_1";
    my $schema = { column1 => 'INT',
                   column2 => 'VARCHAR(16)',
               };

    ok( $sql->create_table( $table, $schema ),
        "Creating a table $table"
    );

    is_deeply( [ $sql->get_tables() ],
               [ $table ],
               "Checking that table was created"
           );

    ok( $sql->insert( $table, { column1 => 123, column2 => "foo", column3 => "abc" }, $schema ),
        "Inserting hash into table"
    );

    is( ( $sql->query( "SELECT * FROM $table" ) )[0]->{column2},
        'foo',
        "Selecting row just inserted into table and checking column value"
    );

    is( ( $sql->query( "SELECT * FROM $table" ) )[0]->{column3},
        undef,
        "Checking that key not defined in schema was not inserted into table"
    );

    ok( $sql->delete( $table, { column1 => 123 } ),
        "Deleting entry just added"
    );

    is_deeply( [ $sql->query( "SELECT * FROM $table" ) ],
               [],
               "Checking that no rows left in the table"
           );

    $schema->{column3} = 'VARCHAR(32)';

    ok( $sql->insert( $table, { column1 => 234, column2 => "bar", column3 => "baz" }, $schema ),
        "Inserting hash with modified schema to include column3"
    );

    is( ( $sql->query( "SELECT * FROM $table" ) )[0]->{column3},
        'baz',
        "Selecting column3 just inserted into table and checking column value"
    );

}

{
    my $table = "test_table_2";
    my $schema = { column1 => 'INT',
                   column2 => 'VARCHAR(16)',
               };

    ok( $sql->insert( $table, { column1 => 123, column2 => "foo" }, $schema ),
        "Inserting hash into non-existent table"
    );

    is( ( $sql->query( "SELECT * FROM $table" ) )[0]->{column2},
        'foo',
        "Checking that table was created and data was inserted and retrieved"
    );

}

{
    my $table = "test_table_3";
    my $schema = { id      => 'INTEGER PRIMARY KEY AUTOINCREMENT',
                   column1 => 'INT',
               };

    is( $sql->insert( $table, { column1 => 123 }, $schema ),
        1,
        "Inserting hash into table, checking returned id"
    );

    is( $sql->insert( $table, { column1 => 234 }, $schema ),
        2,
        "Inserting hash into table, checking returned id"
    );

    is( $sql->insert( $table, { column1 => 345 }, $schema ),
        3,
        "Inserting hash into table, checking returned id"
    );

    is( ( $sql->query( "SELECT * FROM $table" ) )[0]->{id},
        1,
        "Checking auto-incrementing id"
    );

    is( ( $sql->query( "SELECT * FROM $table" ) )[1]->{id},
        2,
        "Checking auto-incrementing id"
    );
}


{
    my $table = "test_table_4";
    my $schema = { column1 => 'INT' };

    ok( $sql->insert( $table, { column1 => 0 }, $schema ),
        "Inserting hash into table with data value 0"
    );

    is( ( $sql->query( "SELECT * FROM $table" ) )[0]->{column1},
        0,
        "Checking that 0 was returned on query"
    );
}

{
    my $table = "test_table_5";
    my $schema = { column1 => 'INT', column2 => 'TEXT', column3 => 'INT', column4 => 'INT', column5 => 'INT' };

    my $data1 = { column1 => 1, column2 => 'foo foo foo', column3 => 3, column4 => 1, column5 => 0 };
    ok( $sql->insert( $table, $data1, $schema ),
        "Inserting test data 1 into table"
    );

    my $data2 = { column1 => 2, column2 => 'bar bar', column3 => 2, column4 => 1, column5  => 1 };
    ok( $sql->insert( $table, $data2, $schema ),
        "Inserting test data 2 into table"
    );

    my $data3 = { column1 => 3, column2 => 'baz', column3 => 1, column4 => 0, column5 => 1 };
    ok( $sql->insert( $table, $data3, $schema ),
        "Inserting test data into table"
    );

    {
        my @rows;
        ok( $sql->select( { tablename  => $table,
                            callback   => sub { push @rows, $_[0] },
                        } ),
            "Selecting all rows in table"
        );
        is_deeply( \@rows,
                   [ $data1, $data2, $data3 ],
                   "Selecting all rows"
               );
    }
    {
        my @rows;
        ok( $sql->select( { tablename => $table,
                            order     => 'column3',
                            callback  => sub { push @rows, $_[0] },
                        } ),
            "Selecting all rows in table ordered by column3"
        );
        is_deeply( \@rows,
                   [ $data3, $data2, $data1 ],
                   "Selecting all rows"
               );
    }
    {
        my @rows;
        ok( $sql->select( { tablename => $table,
                            order     => 'column3',
                            limit     => 1,
                            callback  => sub { push @rows, $_[0] },
                        } ),
            "Selecting all rows in table ordered by column3 with limit 1"
        );
        is_deeply( \@rows,
                   [ $data3 ],
                   "Selecting matching rows"
               );
    }
    {
        my @rows;
        ok( $sql->select( { tablename => $table,
                            order     => 'column3',
                            where     => { column4 => 1,
                                           column5 => 1,
                                       },
                            callback  => sub { push @rows, $_[0] },
                        } ),
            "Selecting all rows in table with conditions column4 = 1 and column5 = 1"
        );
        is_deeply( \@rows,
                   [ $data2 ],
                   "Selecting matching rows"
               );
    }
}


{
    my $table = "test_table_6";
    my $schema = { column1 => 'INT', column2 => 'INT', column3 => 'INT' };

    my $data1 = { column1 => 0, column2 => 1, column3 => 2 };
    ok( $sql->insert( $table, $data1, $schema ),
        "Inserting data1 hash into table"
    );

    my $data2 = { column1 => 4, column2 => 5, column3 => 6 };
    ok( $sql->insert( $table, $data2, $schema ),
        "Inserting data2 hash into table"
    );

    is_deeply( [ $sql->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking inserted data"
           );

    my $error;
    my ( $stdout, $stderr ) = Capture::Tiny::capture {
        eval {
            $sql->update( $table, { column1 => 7 }, { column1 => 0 } );
        };

        $error = $@;
    };

    like( $error,
          qr/no schema specified, and global schema not found for table: $table/,
          "Checking that exception thrown when running a sql update without providing schema",
      );

    like( $stderr,
          qr/no schema specified, and global schema not found for table: $table/,
          "Checking that exception thrown when running a sql update without providing schema",
      );

    ok( $sql->update( $table, { column1 => 7 }, { column1 => 0 }, $schema ),
        "Calling update() to set column1 to 7 where column1 was 0"
    );

    $data1->{column1} = 7;

    is_deeply( [ $sql->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking row was updated"
           );
}


{
    my $table = "test_table_7";
    my $schema = { column1 => 'INT', column2 => 'INT', column3 => 'INT' };

    my $data1 = { column1 => 0, column2 => 1, column3 => 2 };
    ok( $sql->insert( $table, $data1, $schema ),
        "Inserting data1 hash into table"
    );

    my $data2 = { column1 => 4, column2 => 5, column3 => 6 };
    ok( $sql->insert( $table, $data2, $schema ),
        "Inserting data2 hash into table"
    );

    is_deeply( [ $sql->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking inserted data before calling update()"
           );

    $schema->{column4} = 'INT';

    ok( $sql->update( $table, { column4 => 7 }, { column1 => 0 }, $schema ),
        "Calling update() with updated schema containing column4"
    );

    $data1->{column4} = 7;
    $data2->{column4} = undef;

    is_deeply( [ $sql->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking row was updated with column4 data"
           );
}
{
    my $table = "test_table_8";
    my $schema = { column1 => 'INT', column2 => 'INT', column3 => 'INT' };

    my $data1 = { column1 => 0, column2 => 1, column3 => 2 };

    ok( $sql->insert_or_update( $table, $data1, { column1 => 3 }, $schema ),
        "Inserting data2 hash into table with insert_or_update and no pre-existing row"
    );

    my $data2 = { column1 => 4, column2 => 5, column3 => 6 };
    ok( $sql->insert_or_update( $table, $data2, { column1 => 7 }, $schema ),
        "Inserting data2 hash into table with insert_or_update and no pre-existing row"
    );

    is_deeply( [ $sql->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking inserted data before calling update()"
           );

    ok( $sql->insert_or_update( $table, { column1 => 7 }, { column1 => 0 }, $schema ),
        "Calling insert_or_update with row that already exists"
    );

    $data1->{column1} = 7;

    is_deeply( [ $sql->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking existing row was updated with insert_or_update"
           );
}

{
    my $table = "test_table_9";
    my $schema = { column1     => 'INT',
                   column2     => 'INT',
                   column3     => 'INT',
                   constraints => [ 'UNIQUE( column1, column2 )' ],
               };

    my $data1 = { column1 => 1, column2 => 2, column3 => 3 };
    ok( $sql->insert( $table, $data1, $schema ),
        "Inserting first new hash into table"
    );

    my $data2 = { column1 => 4, column2 => 5, column3 => 6 };
    ok( $sql->insert( $table, $data2, $schema ),
        "Inserting second new hash into table"
    );

    is_deeply( [ $sql->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking inserted data"
           );

    {
        ok( ! $sql->insert( $table, $data1, $schema ),
            "Inserting duplicate data into column violates unique constraint"
        );
    }

    {
        my $data3 = { column1 => 1, column2 => 2, column3 => 7 };
        ok( ! $sql->insert( $table, $data3, $schema ),
            "Inserting data into column that violates unique constraint on column1 and column2"
        );
    }

    {
        ok( ! $sql->update( $table, $data2, $data1, $schema ),
            "Updating data2 to match data1 violates unique constraint on column1 and column2"
        );
    }

    {
        ok( ! $sql->insert_or_update( $table, $data2, $data1, $schema ),
            "insert_or_update data2 to match data1 violates unique constraint on column1 and column2"
        );
    }

    is_deeply( [ $sql->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking inserted data"
           );

}

{
    my $table = "test_table_10";
    my $schema = { column1 => 'INT',
                   column2 => 'VARCHAR(16)',
               };

    $sql->create_table( $table, $schema );
    $sql->insert( $table, { column1 => 123, column2 => "foo1" }, $schema );
    $sql->insert( $table, { column1 => 234, column2 => "foo2" }, $schema );
    $sql->insert( $table, { column1 => 345, column2 => "foo3" }, $schema );

    ok( $sql->delete( $table, { column1 => { '>' => 123 } } ),
        "Deleting entries > 123"
    );

    is_deeply( [ $sql->query( "SELECT * FROM $table" ) ],
               [ { column1 => 123, column2 => "foo1" } ],
               "Checking that only one row left in the table"
           );

}


{
    my $table = "test_table_11";
    my $schema = { column1 => 'INT',
                   column2 => 'VARCHAR(16)',
                   constraints => [ 'UNIQUE( column1 )' ],
               };

    $sql->create_table( $table, $schema );

    ok( $sql->insert( $table, { column1 => 123, column2 => "foo1" }, $schema ),
        "Inserting first row into table"
    );

    ok( ! $sql->insert( $table, { column1 => 123, column2 => "foo2" }, $schema ),
        "failing to insert row that violates constraint"
    );

    is_deeply( [ $sql->query( "SELECT * FROM $table" ) ],
               [ { column1 => 123, column2 => "foo1" } ],
               "Checking that only one row left in the table"
           );

}

{
    my $table = "test_table_12";
    my $schema = { column1 => 'INT',
                   column2 => 'VARCHAR(16)',
                   constraints => [ 'UNIQUE( column1 ) ON CONFLICT REPLACE' ],
               };

    ok( $sql->create_table( $table, $schema ),
        "Creating table with UNIQUE constraint and ON CONFLICT REPLACE"
    );

    ok( $sql->insert( $table, { column1 => 123, column2 => "foo1" }, $schema ),
        "Inserting first row into table"
    );

    ok( $sql->insert( $table, { column1 => 123, column2 => "foo2" }, $schema ),
        "inserting row that should replace first row due to constraint"
    );

    is_deeply( [ $sql->query( "SELECT * FROM $table" ) ],
               [ { column1 => 123, column2 => "foo2" } ],
               "Checking that second row replaced first table due to ON CONFLICT REPLACE constraint"
           );

}

# schemas yaml file
{

    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $sqldb = "$tempdir/test.sql";

    my $schema_file = "$tempdir/test.yaml";
    my $test_schema = { xyz => { abc => 'INT',
                                 def => 'TEXT',
                             } };
    YAML::DumpFile( $schema_file, $test_schema );

    my $global_schema_file = "$tempdir/global.yaml";
    my $test_global_schema = { xyz => { abc => 'TEXT',
                                        def => 'TEXT',
                                    },
                               foo => { bar => 'INT',
                                        baz => 'TEXT',
                                    },
                           };
    YAML::DumpFile( $global_schema_file, $test_global_schema );

    ok( my $sql = Wubot::SQLite->new( { file               => $sqldb,
                                        schema_file        => $schema_file,
                                        global_schema_file => $global_schema_file,
                                    } ),
        "Creating new Wubot::SQLite object"
    );

    is( $sql->schema_file(),
        $schema_file,
        "Checking that schema file configured on sql object"
    );

    is( $sql->global_schema_file(),
        $global_schema_file,
        "Checking that global schema file configured on sql object"
    );

    is_deeply( $sql->sql_schemas(),
               { xyz => { abc => 'INT',
                          def => 'TEXT',
                      },
                 foo => { bar => 'INT',
                          baz => 'TEXT',
                      },
             },
               "Checking that test schemas were read, and user schema overrides global schema"
           );

    my $table = "xyz";

    ok( $sql->create_table( $table ),
        "Creating table, using schema from schema file"
    );

    ok( $sql->insert( $table, { abc => 123, def => 456, ghi => 789 } ),
        "Inserting data, using schema in schema file"
    );

    is_deeply( [ $sql->query( "SELECT * FROM $table" ) ],
               [ { abc => 123, def => 456 } ],
               "Checking that defined columns inserted into table"
           );


}

ok( $sql->disconnect(),
    "Closing SQLite file"
);

throws_ok( sub { $sql->query( "SELECT * FROM test_table_2" ) },
           qr/prepare failed.*inactive database handle/,
           "Checking that exception thrown when running a sql query on dead sql handle",
       );

