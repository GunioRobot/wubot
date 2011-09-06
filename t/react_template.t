#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More 'no_plan';

use App::Wubot::Logger;
use App::Wubot::LocalMessageStore;
use App::Wubot::Reactor::Template;

ok( my $template = App::Wubot::Reactor::Template->new(),
    "Creating new Template reactor object"
);

is_deeply( $template->react( { a => 'b' }, { } ),
           { a => 'b' },
           "No template config"
       );

# template string
is_deeply( $template->react( { a => 'b' }, { template => '{$a}', target_field => 'c' } ),
           { a => 'b', c => 'b' },
           "Creating a very simple template with target field"
       );

is_deeply( $template->react( { a => 'b' }, { template => 'x {$a}y', target_field => 'c' } ),
           { a => 'b', c => 'x by' },
           "Creating another simple template with target field"
       );

# source_field
is_deeply( $template->react( { a => 'b', x => '{$a}' }, { source_field => 'x', target_field => 'c' } ),
           { a => 'b', x => '{$a}', c => 'b' },
           "Creating template using 'source_field' param to define the template"
       );

is_deeply( $template->react( { a => 'b', x => 'x {$a}y' }, { source_field => 'x', target_field => 'c' } ),
           { a => 'b', x => 'x {$a}y', c => 'x by' },
           "Creating another template using 'source_field' param to define the template"
       );

# template_file
{
    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
    my $file = "$tempdir/test.tmpl";

    my $template_contents =<<'EOF';

foo

bar {$a} bar

baz

EOF

    open(my $fh, ">", $file)
        or die "Couldn't open $file for writing: $!\n";
    print $fh $template_contents;
    close $fh or die "Error closing file: $!\n";

    is_deeply( $template->react( { a => 'b' }, { template_file => $file, target_field => 'c' } ),
               { a => 'b', c => "\nfoo\n\nbar b bar\n\nbaz\n\n" },
               "Creating template using 'source_field' param to define the template"
           );

}
