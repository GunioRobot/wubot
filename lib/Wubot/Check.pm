package Wubot::Check;
use Moose;

use Benchmark;
use Log::Log4perl;
use YAML;

use Wubot::LocalMessageStore;
use Wubot::Reactor;

has 'key'      => ( is => 'ro',
                    isa => 'Str',
                    required => 1,
                );

has 'class'      => ( is => 'ro',
                      isa => 'Str',
                      required => 1,
                  );

has 'instance'   => ( is      => 'ro',
                      lazy    => 1,
                      default => sub {
                          my $self = shift;
                          my $class = $self->class;
                          eval "require $class";  ## no critic
                          if ( $@ ) {
                              die "ERROR: loading class: $class => $@";
                          }
                          return $class->new( key        => $self->key,
                                              class      => $self->class,
                                              cache_file => $self->cache_file,
                                              reactor    => $self->reactor,
                                          );
                      },
                  );

has 'cache_file' => ( is => 'ro',
                      isa => 'Str',
                      required => 1,
                  );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'reactor_queue' => ( is => 'ro',
                         isa => 'Wubot::LocalMessageStore',
                         lazy => 1,
                         default => sub {
                             return Wubot::LocalMessageStore->new();
                         }
                     );

has 'reactor_queue_dir' => ( is => 'ro',
                             isa => 'Str',
                             default => sub {
                                 return join( "/", $ENV{HOME}, "wubot", "reactor" );
                             },
                         );

has 'reactor'   => ( is => 'ro',
                     isa => 'CodeRef',
                     lazy => 1,
                     default => sub {
                         my ( $self ) = @_;

                         return sub {
                             my ( $message ) = @_;

                             unless ( ref $message eq "HASH" ) {
                                 my ($package, $file, $line) = caller();
                                 warn "ERROR: react() called without a hash: $package:$line: ", YAML::Dump $message;
                                 return;
                             }

                             $self->enqueue_results( $message );
                         };
                     },
                 );

has 'wubot_reactor' => ( is => 'ro',
                         isa => 'Wubot::Reactor',
                         lazy => 1,
                         default => sub {
                             Wubot::Reactor->new();
                         },
                     );

sub init {
    my ( $self, $config ) = @_;

    if ( $self->instance->can( 'validate_config' ) ) {
        $self->instance->validate_config( $config );
    }

    return unless $self->instance->can( 'init' );

    my $cache = $self->instance->get_cache();

    my $results = $self->instance->init( { config => $config, cache => $cache } );

    if ( $results->{react} ) {
        $self->react_results( $results->{react}, $config );
    }

    if ( $results->{cache} ) {
        $self->instance->write_cache( $results->{cache} );
    }

    return $results;
}

sub check {
    my ( $self, $config ) = @_;

    my $cache = $self->instance->get_cache() || {};

    $self->logger->debug( "calling check for instance: ", $self->key );

    my $start = new Benchmark;

    my $timeout = 30;
    if ( $config->{timeout} ) {
        $timeout = $config->{timeout};
    }

    my $results;
    eval {
        # set the alarm
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm $timeout;

        $results = $self->instance->check( { config => $config, cache => $cache } );

        # cancel the alarm
        alarm 0;
    };

    my $error = $@;

    my $end = new Benchmark;
    my $diff = timediff( $end, $start );
    $self->logger->debug( $self->key, ":", timestr( $diff, 'all' ) );

    if ( $error ) {
        if ( $error eq "alarm\n" ) {
            $self->logger->error( "Timed out after $timeout seconds for check: ", $self->key );
        }
        else {
            $self->logger->error( "Check died: $error" );
        }
        return;
    }

    if ( $results->{react} ) {
        $self->react_results( $results->{react}, $config );
    }

    if ( $results->{cache} ) {
        $self->instance->write_cache( $results->{cache} );
    }

    # todo: always touch 'cache' file with latest date

    return $results;
}

sub react_results {
    my ( $self, $react, $config ) = @_;

    if ( ref $react eq "ARRAY" ) {
        for my $results_h ( @{ $react } ) {
            $self->react_results( $results_h, $config );
        }
        return;
    }

    unless ( ref $react eq "HASH" ) {
        $self->logger->error( "React results called without a hash ref: ", YAML::Dump $react );
        return;
    }

    # push any configured 'tags' along with the message
    if ( $config->{tags} ) {
        $react->{tags} = $config->{tags};
    }

    if ( $config->{react} ) {
        $self->logger->debug( "Running reaction configured directly on check instance" );
        $self->wubot_reactor->react( $react, $config->{react} );
    }

    if ( $react->{no_more_rules} ) {
        $self->logger->debug( " - check instance reaction set no_more_rules" );
        $self->logger->trace( YAML::Dump $react );
    }
    else {
        $self->logger->debug( " - sending check results to queue" );
        $self->reactor->( $react );
    }
}

sub enqueue_results {
    my ( $self, $results ) = @_;

    return unless $results;

    unless ( ref $results eq "HASH" ) {
        my ($package, $file, $line) = caller();
        warn "ERROR: enqueue_results called without a hash: $package:$line: ", YAML::Dump $results;
        return;
    }

    # use our class name for the 'plugin' field
    unless ( $results->{plugin} ) {
        $results->{plugin}     = $self->{class};
    }

    # use our instance key name for the 'key' field
    unless ( $results->{key} ) {
        $results->{key}        = $self->key;
    }

    $self->reactor_queue->store( $results, $self->reactor_queue_dir );

}

1;
