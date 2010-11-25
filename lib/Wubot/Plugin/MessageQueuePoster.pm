package Wubot::Plugin::MessageQueuePoster;
use Moose;

use Growl::Tiny;
use LWP::UserAgent;
use HTTP::Request::Common qw{ POST };
use CGI;
use Log::Log4perl;
use YAML;
use Sys::Hostname;

my $hostname = hostname();
$hostname =~ s|\..*$||;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

with 'Wubot::Plugin::Roles::RetryDelay';

sub init {
    my ( $self, $config, $cache ) = @_;

    # schedule next retry immediately, then go back to waiting on the
    # normal delay count
    $cache->{next_retry} = time;

    return $cache;
}

sub check {
    my ( $self, $config, $cache ) = @_;

    my $now = time;
    if ( $cache->{next_retry} && $cache->{next_retry} > $now ) {
        return ( undef, $cache );
    }

    my @files;

    my $dir_h;
    opendir( $dir_h, $config->{directory} ) or die "Can't opendir $config->{directory}: $!";
    while ( defined( my $entry = readdir( $dir_h ) ) ) {
        next unless $entry;
        next unless $entry =~ m|\.yaml$|;
        push @files, $entry;
    }
    closedir( $dir_h );

    @files = sort { -M "$config->{directory}/$a" <=> -M "$config->{directory}/$b" } @files;

    unless ( scalar @files ) {
        return ( undef, $cache );
    }

    my $max = scalar @files > 10 ? 10 : scalar @files;

  MESSAGE:
    for my $count ( 1 .. $max ) {
        my $file = pop @files;

        unless ( $file ) {
            return ( undef, $cache );
        }

        my $path = "$config->{directory}/$file";

        my $data = YAML::LoadFile( $path );
        $data->{service} = $data->{key};

        my $data_text = YAML::Dump $data;

        my $ua      = LWP::UserAgent->new();
        my $request = POST( $config->{url}, [ 'message' => $data_text ] );
        my $content = $ua->request($request)->as_string();

        if ( $content =~ m|\!OK\!| ) {
            unlink $path;
            $cache->{retry_failures} = 0;
            $cache->{next_retry} = undef;
        }
        else {
            $cache->{retry_failures}++;
            $cache->{next_retry} = $self->get_next_retry_utime( $cache->{retry_failures} );
            my $subject = "$cache->{retry_failures} error(s) sending message, retry after " . scalar localtime( $cache->{next_retry} );
            Growl::Tiny::notify( { title   => 'Wubot Message Queue',
                                   subject => $subject,
                               } );
            warn "MessageQueuePoster: $subject\n";
            last MESSAGE;
        }
    }

    return ( undef, $cache );
}

1;

