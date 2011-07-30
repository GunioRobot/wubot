package Wubot::Plugin::PathLastUpdate;
use Moose;

# VERSION

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
