package Wubot::Plugin::OsxIdle;
use Moose;

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

my $command = "ioreg -c IOHIDSystem";

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

    my $idle_sec;

    for my $line ( split /\n/, `$command` ) {

        # we're looking for the first line containing Idle
        next unless $line =~ m|Idle|;

        # capture idle time from end of line
        $line =~ m|(\d+)$|;
        $idle_sec = $1;

        # divide to get seconds
        $idle_sec /= 1000000000;

        $idle_sec = int( $idle_sec );

        last;
    }

    my $results;

    my $stats;
    ( $stats, $cache ) = $self->calculate_idle_stats( time, $idle_sec, $config, $cache );

    # add all stats to both the cache and results
    for my $stat ( keys %{ $stats } ) {

        if ( defined $stats->{$stat} ) {
            $results->{$stat} = $stats->{$stat};
            $cache->{$stat}   = $stats->{$stat};
        }
        else {
            # value is 'undef', remove it from the cache data
            delete $cache->{$stat};
        }
    }

    $self->logger->debug( "idle_min:$stats->{idle_min} idle_state:$stats->{idle_state} active_min:$stats->{active_min}" );

    return { cache => $cache, react => $results };
}

 sub calculate_idle_stats {
     my ( $self, $now, $seconds, $config, $cache ) = @_;

     my $stats;
     $stats->{idle_sec} = $seconds;
     $stats->{idle_min} = int( $seconds / 60 );

     my $idle_threshold = $config->{idle_threshold} || 10;

     if ( $cache->{lastupdate} ) {
         my $age = $now - $cache->{lastupdate};
         if ( $age >= $idle_threshold*60 ) {
             $self->logger->debug( "OsxIdle: cache expired" );
             $stats->{cache_expired} = 1;
             delete $cache->{last_idle_state};
             delete $cache->{idle_since};
             delete $cache->{active_since};
         }
         else {
             $stats->{cache_expired} = undef;
             $stats->{last_age_secs} = $age;
         }
     }
     else {
         $stats->{cache_expired} = undef;
     }

     $stats->{lastupdate} = $now;

     if ( exists $cache->{idle_state} ) {
         $stats->{last_idle_state} = $cache->{idle_state} || 0;
     }

     $stats->{last_idle_min} = $cache->{idle_min};
     $stats->{idle_state} = $stats->{idle_min} >= $idle_threshold ? 1 : 0;

     if ( exists $stats->{last_idle_state} && $stats->{last_idle_state} != $stats->{idle_state} ) {
         $stats->{idle_state_change} = 1;
     }
     else {
         $stats->{idle_state_change} = undef;
     }

     if ( $stats->{idle_state} ) {
         # user is currently idle
         $stats->{active_since} = undef;

         $stats->{last_active_min} = $cache->{active_min} || 0;
         $stats->{active_min} = 0;


         if ( $cache->{idle_since} ) {
             $stats->{idle_since} = $cache->{idle_since};
         }
         else {
             $stats->{idle_since} = $now - $stats->{idle_sec};
         }
     }
     else {
         # user is currently active

         $stats->{idle_since} = undef;

         if ( $cache->{active_since} ) {
             $stats->{active_since} = $cache->{active_since};
             $stats->{active_min} = int( ( $now - $cache->{active_since} ) / 60 ) - $stats->{idle_min};
         }
         else {
             $stats->{active_since} = $now;
             $stats->{active_min} = 0;
         }

     }

     if ( $stats->{idle_state_change} ) {
         if ( $stats->{idle_state} ) {
             $stats->{subject} = "Idle after being active for $stats->{last_active_min} minutes";
         }
         else {
             $stats->{subject} =  "Active after being idle for $stats->{last_idle_min} minutes";
         }
     }
     elsif ( $stats->{idle_state} ) {
         if ( $stats->{idle_min} % 60 == 0 && $stats->{idle_min} > 0 ) {
             my $hours_idle = int( $stats->{idle_min} / 60 );
             $stats->{subject} = "Idle for $hours_idle hour(s)";
         }
     }
     else {
         if ( $stats->{active_min} % 60 == 0 && $stats->{active_min} > 0 ) {
             my $hours_active = int( $stats->{active_min} / 60 );
             $stats->{subject} = "Active for $hours_active hour(s)";
         }
     }

     if ( $stats->{subject} ) {
         $self->logger->debug( $stats->{subject} );
     }

     return ( $stats, $cache );
 }

1;
