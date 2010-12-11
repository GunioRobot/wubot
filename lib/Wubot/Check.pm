package Wubot::Check;
use Moose;

use Log::Log4perl;
use YAML;

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

                             $self->enqueue_results( $message );
                         };
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
        $self->reactor->( $results->{react} );
    }

    if ( $results->{cache} ) {
        $self->instance->write_cache( $results->{cache} );
    }

    return $results;
}

sub check {
    my ( $self, $config ) = @_;

    my $cache = $self->instance->get_cache();

    $self->logger->debug( "calling check for instance: ", $self->key );

    my $results = $self->instance->check( { config => $config, cache => $cache } );

    if ( $results->{react} ) {
        $self->reactor->( $results->{react} );
    }

    if ( $results->{cache} ) {
        $self->instance->write_cache( $results->{cache} );
    }

    # todo: always touch 'cache' file with latest date

    return $results;
}

sub enqueue_results {
    my ( $self, $results ) = @_;

    return unless $results;

    my @results;
    if ( ref $results eq "ARRAY" ) {
        @results = @{ $results };
    }
    else {
        push @results, $results;
    }

    for my $result ( @results ) {

        # use our class name for the 'plugin' field
        $result->{plugin}     = $self->{class};

        # use our instance key name for the 'key' field
        $result->{key}        = $self->key;

        $self->reactor_queue->store( $result, $self->reactor_queue_dir );
    }
}

1;
