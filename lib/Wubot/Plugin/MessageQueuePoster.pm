package Wubot::Plugin::MessageQueuePoster;
use Moose;

use LWP::UserAgent;
use HTTP::Request::Common qw{ POST };
use CGI;
use YAML;

with 'Wubot::Plugin::Roles::Plugin';
with 'Wubot::Plugin::Roles::Reactor';
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
        return $cache;
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
        return $cache;
    }

    my $max = scalar @files > 10 ? 10 : scalar @files;

    if ( scalar @files > $max ) {
        $self->logger->warn( "MessageQueuePoster: queue length is ", scalar @files );
    }

  MESSAGE:
    for my $count ( 1 .. $max ) {
        my $file = pop @files;

        unless ( $file ) {
            return $cache;
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
            $cache->{last_ok} = $now;
        }
        else {
            $cache->{retry_failures}++;
            $cache->{next_retry} = $self->get_next_retry_utime( $cache->{retry_failures} );
            my $subject = "$cache->{retry_failures} error(s) sending message, retry after " . scalar localtime( $cache->{next_retry} );
            $self->react( { subject => $subject } );
            warn "MessageQueuePoster: $subject\n";
            last MESSAGE;
        }
    }

    return $cache;
}

1;

