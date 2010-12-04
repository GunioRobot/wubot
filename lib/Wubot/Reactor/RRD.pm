package Wubot::Reactor::RRD;
use Moose;

use Capture::Tiny;
use File::Path;
use Log::Log4perl;
use POSIX qw(strftime);
use RRD::Simple;
use YAML;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub react {
    my ( $self, $message, $config ) = @_;

    unless ( $config->{key} ) {
        $self->logger->logdie( "RRD reaction called missing required config param: key" );
    }

    my $time = $message->{lastupdate} || time;

    my $key   = $config->{key};
    my $value = $message->{ $key };

    my $rrd_dir      = join( "/", $config->{base_dir}, "rrd", $message->{key} );
    unless ( -d $rrd_dir ) {
        mkpath( $rrd_dir );
    }

    my $rrd_filename = join( "/", $rrd_dir, "$key.rrd" );

    my $rrd = RRD::Simple->new( file => $rrd_filename );

    unless ( -r $rrd_filename ) {
        $self->logger->warn( "Creating RRD filename: $rrd_filename" );

        $rrd->create( $key => $config->{type} );
    }

    $rrd->update( $rrd_filename, $time, $key, $value );

    # log the value
    if ( $config->{log} ) {
        open(my $fh, ">>", $config->{log})
            or die "Couldn't open $config->{log} for writing: $!\n";
        print $fh join( ", ", scalar localtime( $time ), $key, $value ), "\n";
        close $fh or die "Error closing file: $!\n";
    }

    # graph
    my $period = $config->{period} || "day";

    my $graph_dir = join( "/", $config->{base_dir}, "graphs", $message->{key} );

    unless ( -d $graph_dir ) {
        mkpath( $graph_dir );
    }

    $self->logger->debug( "Regenerating rrd graphs: $graph_dir" );

    my ( $stdout, $stderr ) = Capture::Tiny::capture {
        my %rtn = $rrd->graph( destination => $graph_dir,
                               basename    => $key,
                               periods     => [ $period ],
                               color       => $config->{color} || [ 'BACK#666666', 'CANVAS#333333' ],
                           );
    };

    return $message;
}

1;
