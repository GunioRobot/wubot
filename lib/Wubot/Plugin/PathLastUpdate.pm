package Wubot::Plugin::PathLastUpdate;
use Moose;

# VERSION

use Wubot::Logger;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

use Wubot::TimeLength;
my $timelength = Wubot::TimeLength->new();

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    my $path = $config->{path};

    unless ( -r $path ) {
        return { react => { subject => "path not found: $path" } };
    }

    my $last_modified = ( stat $path )[9];

    my $age = time - $last_modified;

    my $seconds = $timelength->get_seconds( $config->{age} );

    if ( $age > $seconds ) {

        my $time_passed = $timelength->get_human_readable( $age );

        return { react => { subject => "path has not been updated in $time_passed" } };
    }

    return;
}

1;


__END__


=head1 NAME

Wubot::Plugin::PathLastUpdate - monitor the last modified time on a path


=head1 SYNOPSIS

  ~/wubot/config/plugins/PathLastUpdate/scifri.yaml

  ---
  path: /path/to/file
  age: 1w
  delay: 15m

=head1 DESCRIPTION

Monitor the last modified time on a file or directory and send a
notification if the last modified time is older than a configured
threshold.

If the path is not found, a message will be sent containing the
subject:

  path not found: {$path}

If the last modified date of the target path is older than the
specified age, then a message will be sent containing the subject:

  path has not been updated in {$time}

=head1 HINTS

I developed this monitor after being repeatedly aggravated that iTunes
will periodically stop updating a podcast if you do not regularly mark
items in the podcast as being seen.  This can be especially annoying
when podcasts don't always carry all the archived items!  Here is an
example config file I use to monitor the sci-fri directory to let me
know when the feed is not being updated:

  ---
  path: /Users/wu/Music/iTunes/iTunes Media/Podcasts/Science Friday Audio Podcast
  age: 1w1d
  delay: 15m
