package Wubot::Plugin::Roles::RetryDelay;
use Moose::Role;

use Log::Log4perl;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );


sub get_next_retry_utime {
    my ( $self, $retry_count ) = @_;

    my $delay = $retry_count * 2 + 5;

    my $now   = time;

    my $next = $delay + $now;

    $self->logger->debug( "retry_count=$retry_count delay=$delay now=$now retry_next=$next retry_time=" . scalar( localtime( $next ) ) );

    return $next;
}


1;
