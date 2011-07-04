package Wubot::Plugin::WebFetch;
use Moose;

# VERSION

# todo: select with xpath in addition to regexp

use Wubot::Util::WebFetcher;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

has 'fetcher' => ( is  => 'ro',
                   isa => 'Wubot::Util::WebFetcher',
                   lazy => 1,
                   default => sub {
                       return Wubot::Util::WebFetcher->new();
                   },
               );

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};

    my $content;
    eval {                          # try
        $content = $self->fetcher->fetch( $config->{url}, $config );
        1;
    } or do {                       # catch
        my $error = $@;
        my $subject = "Request failure: $error";
        $self->logger->error( $self->key . ": $subject" );
        return { react => { subject => $subject } };
    };

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
