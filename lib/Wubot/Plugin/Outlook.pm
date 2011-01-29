package Wubot::Plugin::Outlook;
use Moose;

use Date::Manip;
use Encode;
use HTML::TableExtract;
use Log::Log4perl;
use LWP::UserAgent;
use YAML;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    my @react;

    my $content = $self->get_content( $config->{url}, $config );

    unless ( $content ) {
        $self->logger->error( "Critical: outlook: No content retrieved!" );
        return;
    }

    my $count = 0;

  MSGID:
    for my $msgid ( $self->get_msgids( $content ) ) {

        # if this id is already in the db, we're done
        next MSGID if $self->cache_is_seen( $cache, $msgid );

        # only get 10 unread messages per iteration
        $count++;
        last MSGID if $count > 10;

        my $msg_url = join '?', $config->{url}, "ae=Item&t=IPM.Note&id=$msgid";
        my $content = $self->get_content( $msg_url, $config );

        next MSGID unless $content;

        my $entry = $self->parse_message( $content, $msg_url );
        $entry->{link} = $msg_url;

        push @react, $entry;

        $self->cache_mark_seen( $cache, $msgid );
    }

    $self->cache_expire( $cache );

    my $results = { cache => $cache, react => \@react };

    if ( $count > 10 ) {
        $results->{delay} = 10;
    }

    return $results;
}

sub get_msgids {
    my ( $self, $content ) = @_;

    my @msgids;

    $content =~ s{name="chkmsg" value="([^"]+)"}{push @msgids, $1}eg;

    my @return;

    for my $msgid ( @msgids ) {
        $msgid =~ s|\/|%2f|g;
        $msgid =~ s|\+|%2b|g;
        push @return, $msgid;
    }

    return reverse @return;
}

sub parse_message {
    my ( $self, $content, $url ) = @_;

    my $te = HTML::TableExtract->new( keep_html => 1 );

    # "Parsing of undecoded UTF-8 will give garbage when decoding entities"
    $content = Encode::decode_utf8( $content );

    $te->parse( $content );

    my @headers;

    # extract the headers
    $content =~ m|(<table class="msgHd".*?</table>)|s;
    my $header = $1;

    unless ( $header ) {
        die "ERROR: no message retrieved!"
    }

    my $header_data;

    for my $row ( split /\<tr\s*\>/, $header ) {
        $row =~ s|^\s+||mg;
        #print "ROW: $row\n";

        if ( $row =~ m|<td[^>]+class="(\w+)">| ) {

            my $class = $1;
            #print "CLASS: $class\n";

            if    ( $class eq "sub" ) { $header_data->{subject}  = $row }
            elsif ( $class eq "frm" ) { $header_data->{username} = $row;
                                    }
            elsif ( $class eq "hdtxt" ) {

                my $field_name;

                for my $subrow ( split /\<td/, $row ) {

                    next unless $subrow;

                    if ( $subrow =~ m|class="hdtxt">\s*(.*)\:\s*</td>|s ) {
                        $field_name = $1;
                        #print "FIELD NAME: $field_name\n";
                    }
                    elsif ( $subrow =~ m|class="hdtxnr">\s*(.*)\s*</td>|s ) {
                        my $value = $1;
                        #print "VALUE: $value\n";
                        $header_data->{$field_name} = $value;
                    }
                    else {
                        print "UNPARSED: $subrow\n";
                    }
                }

                #print "\n";


            }
            else {
                #print "UNHANDLED Class: $1\n$row\n\n";
            }
        }
        else {
            #print "NO CLASS:\n$row\n";
        }

    }

    for my $field ( keys %{ $header_data } ) {

        $header_data->{$field} =~ s|^\s+||;
        $header_data->{$field} =~ s|\s+$||;
        $header_data->{$field} =~ s/\<\/?(span|div).*?\>//g;
        $header_data->{$field} =~ s|</a>||g;
        $header_data->{$field} =~ s|<a href.*?>||g;

    }

    unless ( $header ) {
        $self->logger->info( "critical: outlook: Unable to parse outlook page content" );
    }

    my $subject = $header_data->{subject};
    $subject =~ s|^<td.*?>||s;
    $subject =~ s|</td.*$||s;
    $subject =~ s|^[\r\n]+||s;
    $subject =~ s|[\r\n]+$||s;
    #print "OUTLOOK SUBJECT: $subject\n";

    my $username = $header_data->{username};
    $username =~ s|^<td.*?>||s;
    $username =~ s|</td.*$||s;
    $username =~ s|^[\r\n]+||s;
    $username =~ s|[\r\n]+$||s;
    #print "USERNAME: $username\n";

    my $sent = $header_data->{Sent};
    my $sent_utime = UnixDate( ParseDate( $sent ), "%s" );
    #print "SENT: $sent [$sent_utime]\n";

    my $to_user = $header_data->{To};
    #print "TO: $to_user\n";

    # extract the body
    my $body = $content;
    $body =~ s|^.*\<td class\=\"bdy\"\>||s;
    $body =~ s|<td class\=\"nvft\"\>.*$||s;
    $body =~ s|^(.*)<\/div>.*$|$1|sg;
    $body =~ s|^\s+<div |<div |mg;
    $body = Encode::encode_utf8( $body );
    $body =~ s|\r||g;
    $body =~ s|\s*$||mg;
    #print "BODY: $body\n";
    #$body =~ s|img[^\<\>]+src="attachment.ashx|img src="$url/attachment.ashx|sg;

    # fix chars
    $body =~ s|\xe2\x80\x93|-|g;
    $body =~ s|\xe2\x80\x98|'|g;
    $body =~ s|\xe2\x80\x99|'|g;
    $body =~ s|\xe2\x80\xa6|...|g;

    utf8::decode( $body );

    my $entry = { subject    => $subject,
                  username   => $username,
                  sent       => $sent,
                  lastupdate => $sent_utime,
                  to_user    => $to_user,
                  body       => $body,
              };

    #$entry->{body} = Encode::encode_utf8( $entry->{body} );
    #print YAML::Dump $entry->{body};

    return $entry;
}

sub get_content {
    my ( $self, $url, $config ) = @_;

    my $ua = new LWP::UserAgent;
    $ua->timeout(15);

    if ( $config->{proxy} ) {
        $ua->proxy(['http'],  $config->{proxy} ); # set proxy
        $ua->proxy(['https'], $config->{proxy} ); # set proxy
    }

    $ua->agent("Mozilla/6.0");  # Or something equally mysterious

    my $req = new HTTP::Request GET => $url;
    $req->authorization_basic( $config->{user}, $config->{pass} );

    my $res = $ua->request($req);

    unless ($res->is_success) {
        $self->logger->warn( "Failure checking outlook web: " . $res->status_line );
        return;
    }

    my $content= $res->content;

    return $content;
}

1;
