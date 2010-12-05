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

    unless ( $config->{fields} ) {
        $self->logger->logdie( "RRD reaction called missing required config param: fields" );
    }

    my $time = $message->{lastupdate} || time;

    my $rrd_dir      = join( "/", $config->{base_dir}, "rrd", $message->{key} );
    unless ( -d $rrd_dir ) {
        mkpath( $rrd_dir );
    }

    my $graph_dir = join( "/", $config->{base_dir}, "graphs", $message->{key} );
    unless ( -d $graph_dir ) {
        mkpath( $graph_dir );
    }

    for my $field ( split /,/, $config->{fields} ) {

        my $value = $message->{ $field };

        my $rrd_filename = join( "/", $rrd_dir, "$field.rrd" );

        my $rrd = RRD::Simple->new( file => $rrd_filename );

        unless ( -r $rrd_filename ) {
            $self->logger->warn( "Creating RRD filename: $rrd_filename" );

            $rrd->create( $field => $config->{type} );
        }

        $rrd->update( $rrd_filename, $time, $field, $value );

        # log the value
        if ( $config->{log} ) {
            open(my $fh, ">>", $config->{log})
                or die "Couldn't open $config->{log} for writing: $!\n";
            print $fh join( ", ", scalar localtime( $time ), $field, $value ), "\n";
            close $fh or die "Error closing file: $!\n";
        }

        # graph
        my $period = $config->{period} || "day";

        $self->logger->debug( "Regenerating rrd graphs: $graph_dir" );

        my ( $stdout, $stderr ) = Capture::Tiny::capture {
            my %rtn = $rrd->graph( destination => $graph_dir,
                                   basename    => $field,
                                   periods     => [ $period ],
                                   color       => $config->{color} || [ 'BACK#666666', 'CANVAS#333333' ],
                               );
        };

    }

    return $message;
}

1;
