package Wubot::Plugin::WebFetch;
use Moose;

use LWP::UserAgent;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};

    my $ua = new LWP::UserAgent;

    if ( $config->{timeout} ) {
        $ua->timeout( $config->{timeout} );
    }
    else {
        $ua->timeout(20);
    }

    if ( $config->{agent} ) {
        $ua->agent( $config->{agent} );
    }
    else {
        $ua->agent("Mozilla/6.0");
    }

    if ( $config->{proxy} ) {
        $ua->proxy(['http'],  $config->{proxy} );
        $ua->proxy(['https'], $config->{proxy} );
    }

    my $req = new HTTP::Request GET => $config->{url};

    if ( $config->{user} && $config->{pass} ) {
        $req->authorization_basic( $config->{user}, $config->{pass} );
    }

    my $res = $ua->request($req);

    unless ($res->is_success) {
        return { react => { 'failure getting updates: ' . $res->status_line } };
    }

    my $content = $res->content;
    #print "CONTENT: $content\n";

    my $message;

    for my $regexp_name ( keys %{ $config->{regexp} } ) {

        my $regexp = $config->{regexp}->{ $regexp_name };
        #print "Checking content for regexp: $regexp_name => $regexp\n";

        if ( $content =~ m|$regexp|s ) {
            $message->{ $regexp_name } = $1;
        }
    }

    return { react => $message };
}

1;
