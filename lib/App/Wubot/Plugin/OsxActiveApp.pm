package App::Wubot::Plugin::OsxActiveApp;
use Moose;

# VERSION

use App::Wubot::Logger;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );


with 'App::Wubot::Plugin::Roles::Cache';
with 'App::Wubot::Plugin::Roles::Plugin';

my $command =<<EOF;

/usr/bin/python -c "
from AppKit import NSWorkspace
activeAppName = NSWorkspace.sharedWorkspace().activeApplication()['NSApplicationName']
print activeAppName
"

EOF

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

    my $output = `$command`;

    chomp $output;

    return { react => { application => $output } };
}

1;

__END__

=head1 NAME

App::Wubot::Plugin::OsxActiveApp - monitor current active application in OS X

=head1 SYNOPSIS

  ~/wubot/config/plugins/OsxActiveApp/navi.yaml

  ---
  enable: 1


=head1 DESCRIPTION

Runs a little python command-line script (see the source) to determine
which application is currently active in OS X.

Sends a message containing:

  application: {appname}


=head1 SUBROUTINES/METHODS

=over 8

=item check( $inputs )

The standard monitor check() method.

=back
