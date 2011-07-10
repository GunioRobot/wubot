package Wubot::Reactor::Command;
use Moose;

# VERSION

use Log::Log4perl;
use POSIX qw(strftime);
use Term::ANSIColor;

has 'logger'  => ( is       => 'ro',
                   isa      => 'Log::Log4perl::Logger',
                   lazy     => 1,
                   default  => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub react {
    my ( $self, $message, $config ) = @_;

    my $output = "";

    if ( $config->{command} ) {
        $output = `$config->{command} 2>&1`;
    }
    elsif ( $config->{command_field} ) {
        my $command = $message->{ $config->{command_field} };
        $output = `$command 2>&1`;
    }

    chomp $output;

    if ( $config->{output_field} ) {
        $message->{ $config->{output_field} } = $output;
    }
    else {
        $message->{command_output} = $output;
    }

    return $message;
}

1;
