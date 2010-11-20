package Wubot::Plugin::MessageQueuePoster;
use Moose;

use LWP::UserAgent;
use HTTP::Request::Common qw{ POST };
use CGI;
use YAML;
use Sys::Hostname;

my $hostname = hostname();

sub check {
    my ( $self, $config, $cache ) = @_;

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

    return unless scalar @files;

    my $file = pop @files;
    return unless $file;

    my $path = "$config->{directory}/$file";

    my $data = YAML::LoadFile( $path );
    $data->{service} = "wubot-$hostname";

    my $data_text = YAML::Dump $data;

    my $ua      = LWP::UserAgent->new();
    my $request = POST( $config->{url}, [ 'message' => $data_text ] );
    my $content = $ua->request($request)->as_string();

    if ( $content =~ m|\!OK\!| ) {
        unlink $path;
    }
    else {
        warn "ERROR: enable to verify message received: $path\n";
    }

    return ( undef,
             $cache,
         );
}

1;

