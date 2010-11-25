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
                          return $class->new( key     => $self->key,
                                              reactor => $self->reactor,
                                              class   => $self->class,
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

    my $cache_data = $self->get_cache();

    my ( $cache ) = $self->instance->init( $config, $cache_data );

    $self->write_cache( $cache );
}

sub get_cache {
    my ( $self ) = @_;

    # read the cache data
    my $cache_data = {};
    if ( -r $self->cache_file ) {
        $cache_data = YAML::LoadFile( $self->cache_file );
    }

    return $cache_data;
}

sub write_cache {
    my ( $self, $cache ) = @_;

    YAML::DumpFile( $self->cache_file, $cache );

}

sub check {
    my ( $self, $config ) = @_;

    my $cache_data = $self->get_cache();

    $self->logger->debug( "calling check for instance: ", $self->key );

    my $cache = $self->instance->check( $config, $cache_data );

    # store the latest check cache data
    $cache->{lastupdate} = time;

    $self->write_cache( $cache );

}

1;
