package Wubot::Plugin::MessageQueuePoster;
use Moose;

use LWP::UserAgent;
use HTTP::Request::Common qw{ POST };
use CGI;
use YAML;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';
with 'Wubot::Plugin::Roles::Reactor';
with 'Wubot::Plugin::Roles::RetryDelay';

sub init {
    my ( $self, $config ) = @_;

    # schedule next retry immediately, then go back to waiting on the
    # normal delay count
    $self->cache->{next_retry} = time;

}

sub check {
    my ( $self, $config ) = @_;

    my $now = time;
    if ( $self->cache->{next_retry} && $self->cache->{next_retry} > $now ) {
        return;
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
        return;
    }

    my $max = scalar @files > 10 ? 10 : scalar @files;

    if ( scalar @files > $max ) {
        $self->logger->warn( "MessageQueuePoster: queue length is ", scalar @files );
    }

  MESSAGE:
    for my $count ( 1 .. $max ) {
        my $file = pop @files;

        unless ( $file ) {
            return;
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
            $self->cache->{retry_failures} = 0;
            $self->cache->{next_retry} = undef;
            $self->cache->{last_ok} = $now;
        }
        else {
            $self->cache->{retry_failures}++;
            $self->cache->{next_retry} = $self->get_next_retry_utime( $self->cache->{retry_failures} );
            my $subject = "$self->{cache}->{retry_failures} error(s) sending message, retry after " . scalar localtime( $self->cache->{next_retry} );
            $self->react( { subject => $subject } );
            warn "MessageQueuePoster: $subject\n";
            last MESSAGE;
        }
    }

    return 1;
}

1;

