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

    my %rrd_data;
    for my $field ( sort keys %{ $config->{fields} } ) {
        $rrd_data{$field} = $message->{$field};
    }

    my $filename = $config->{filename} || $message->{key} || 'data';
    my $rrd_filename = join( "/", $rrd_dir, "$filename.rrd" );

    my $rrd = RRD::Simple->new( file => $rrd_filename );

    unless ( -r $rrd_filename ) {
        $self->logger->warn( "Creating RRD filename: $rrd_filename" );

        $rrd->create( %{ $config->{fields} } );
    }

    # if rrd heartbeat configured, ensure the heartbeat is set on all data sources
    if ( $config->{heartbeat} ) {
        for my $field ( sort keys %{ $config->{fields} } ) {
            unless ( $config->{heartbeat} == $rrd->heartbeat( $rrd_filename, $field ) ) {
                $rrd->heartbeat( $rrd_filename, $field, $config->{heartbeat} );
            }
        }
    }

    $rrd->update( $rrd_filename, $time, %rrd_data );

    # log the value
    if ( $config->{log} ) {
        open(my $fh, ">>", $config->{log})
                or die "Couldn't open $config->{log} for writing: $!\n";

        for my $field ( keys %rrd_data ) {
            print $fh join( ", ", scalar localtime( $time ), $field, $rrd_data{$field} ), "\n";
        }

        close $fh or die "Error closing file: $!\n";
    }

    # graph
    my $period = $config->{period} || [ 'day' ];

    $self->logger->debug( "Regenerating rrd graph: $graph_dir" );

    my %graph_options = ( destination => $graph_dir,
                          basename    => $filename,
                          periods     => $period,
                          color       => $config->{color} || [ 'BACK#666666', 'CANVAS#333333' ],
                      );

    if ( $config->{graph_options} ) {
        for my $option ( keys %{ $config->{graph_options} } ) {
            $graph_options{ $option } = $config->{graph_options}->{ $option };
        }
    }

    my ( $stdout, $stderr ) = Capture::Tiny::capture {
        my %rtn = $rrd->graph( %graph_options );
    };

    return $message;
}

1;
