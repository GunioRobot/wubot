package Wubot::Check;
use Moose;

use Log::Log4perl;
use Digest::MD5 qw( md5_hex );
use YAML;
use Sys::Hostname qw();

has 'hostname' => ( is => 'ro',
                    isa => 'Str',
                    lazy => 1,
                    default => sub {
                        my $hostname = Sys::Hostname::hostname();
                        $hostname =~ s|\..*$||;
                        return $hostname;
                    },
                );

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
                          return $class->new( key => $self->key );
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

    my ( $results, $cache ) = $self->instance->check( $config, $cache_data );

    # store the latest check cache data
    $cache->{lastupdate} = time;

    $self->write_cache( $cache );

    if ( $results ) {
        for my $result ( @{ $results } ) {
            next unless $results;

            $result->{checksum}   = $self->checksum( $result );
            $result->{lastupdate} = $cache->{lastupdate};
            $result->{plugin}     = $self->{class};
            $result->{key}        = $self->{key};
            $result->{hostname}  = $self->hostname;

            $self->reactor->( $result );
        }
    }

    return $results;
}


sub checksum {
    my ( $self, $message ) = @_;

    return md5_hex( YAML::Dump $message );
}

1;
