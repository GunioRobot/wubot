package Wubot::Plugin::CommandRegex;
use Moose;

# VERSION

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    $self->logger->debug( "CommandRegex command: $inputs->{config}->{command}");
    my $command_output = `$inputs->{config}->{command}`;
    $self->logger->debug( "CommandRegex: $inputs->{config}->{command} $command_output");
    my $regex = $inputs->{config}->{regex};
    $self->logger->debug( "CommandRegex regex: $inputs->{config}->{regex}");
    my $subject;
	if ($command_output =~ m|$regex|) {
		$subject = $1;
	    $self->logger->info( "CommandRegex: $inputs->{config}->{command} $command_output $regex $subject");
	}
    my $status = "ok";
    my $results = { status  => $status, };

    if ( $subject ) {
        $results->{subject} = $subject;
    }

    return { react => $results };
}

1;
