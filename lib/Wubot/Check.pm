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
                      isa      => 'CodeRef',
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

    return unless $self->instance->can( 'init' );

    $self->instance->get_cache();

    $self->instance->init( $config );

    $self->instance->write_cache();
}

sub check {
    my ( $self, $config ) = @_;

    $self->instance->get_cache();

    $self->logger->debug( "calling check for instance: ", $self->key );

    $self->instance->check( $config );

    $self->instance->write_cache();
}

1;
