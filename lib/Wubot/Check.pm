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
                          eval "require $class";
                          if ( $@ ) {
                              die "ERROR: loading class: $class => $@";
                          }
                          return $class->new( key        => $self->key,
                                              reactor    => $self->reactor,
                                              class      => $self->class,
                                              cache_file => $self->cache_file,
                                          );
                      },
                  );

has 'cache_file' => ( is => 'ro',
                      isa => 'Str',
                      required => 1,
                  );

has 'reactor'    => ( is       => 'ro',
                      isa      => 'Wubot::Reactor',
                      required => 1,
                  );


has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
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
        $self->instance->react( $results->{react} );
    }

    if ( $results->{cache} ) {
        $self->instance->write_cache( $results->{cache} );
    }
}

sub check {
    my ( $self, $config ) = @_;

    my $cache = $self->instance->get_cache();

    $self->logger->debug( "calling check for instance: ", $self->key );

    my $results = $self->instance->check( { config => $config, cache => $cache } );

    if ( $results->{react} ) {
        $self->instance->react( $results->{react} );
    }

    if ( $results->{cache} ) {
        $self->instance->write_cache( $results->{cache} );
    }

    # todo: always touch 'cache' file with latest date

}

1;
