#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Test::Exception;
use Test::More 'no_plan';
use YAML;

use Wubot::SQLite;


my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

my $sqldb = "$tempdir/test.sql";

ok( my $sql = Wubot::SQLite->new( { file => $sqldb } ),
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

ok( $sql->disconnect(),
    "Closing SQLite file"
);

throws_ok( sub { $sql->query( "SELECT * FROM test_table_2" ) },
           qr/prepare failed.*inactive database handle/,
           "Checking that exception thrown when running a sql query on dead sql handle",
       );
