package Wubot::Plugin::SafariBookmarks;
use Moose;

# VERSION

use LWP::Simple;
use XML::Simple;

use Wubot::Logger;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

my $file = join( "/", $ENV{HOME}, "library", "Safari", "Bookmarks.plist" );

my $xml = new XML::Simple;

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

    unless ( -r $file ) {
        my $subject = "Error: bookmarks file not found: $file";
        $self->logger->error( $self->key . ": $subject" );
        return { cache => $cache, react => { subject => $subject } };
    }

    my $tmpfile = "/tmp/bookmarks.plist";

    if ( -r $tmpfile ) {
        unlink $tmpfile;
    }

    print "Copying $file to $tmpfile\n";
    system( "cp", $file, $tmpfile );

    print "Converting to xml...\n";
    system( "plutil", "-convert", "xml1", $tmpfile );


    my $data = $xml->XMLin( $tmpfile );

    my $new = {};

    $self->_parse_data( $data, $cache, $new );

    my @react;

    for my $url ( keys %{ $new } ) {
        my $react = { url => $url };

        my $content = get( $url );

        if ( $content =~ m|<title>(.*)</title>|is ) {
            $react->{subject} = $1;
            $react->{subject} =~ s|^[\'\s]+||;
            $react->{subject} =~ s|[\'\s]+$||;
        }
        else {
            $react->{subject} = $url;
        }

        push @react, $react;
    }

    $self->cache_expire( $cache );

    return { cache => $cache, react => \@react };
}

sub _parse_data {
    my ( $self, $data, $cache, $new ) = @_;

    if ( ref $data eq "ARRAY" ) {
        for my $subdata ( @{ $data } ) {
            $self->_parse_data( $subdata, $cache, $new );
        }
        return;
    }

    if ( $data->{dict} ) {
        $self->_parse_data( $data->{dict}, $cache, $new );
    }

    if ( $data->{array} ) {
        $self->_parse_data( $data->{array}, $cache, $new );
    }

    if ( $data->{string} ) {
        if ( ref $data->{string} eq "ARRAY" ) {
            for my $string ( @{ $data->{string} } ) {
                if ( $string =~ m|http\:\/\/| ) {

                    # if we've already seen this item, move along
                    if ( $self->cache_is_seen( $cache, $string ) ) {
                        $self->logger->trace( "Already seen: ", $string );

                        # touch cache time on this subject
                        $self->cache_mark_seen( $cache, $string );

                        next;
                    }

                    $new->{ $string } = 1;

                    # mark this item as new
                    $self->cache_mark_seen( $cache, $string );

                }
            }
        }
    }

}


1;

__END__

=head1 NAME

Wubot::Plugin::SafariBookmarks - monitor a directory for new files

=head1 DESCRIPTION

TODO: More to come...

=head1 SUBROUTINES/METHODS

=over 8

=item check( $inputs )

The standard monitor check() method.

=back
