package Wubot::Plugin::Roles::Reactor;
use Moose::Role;

use Digest::MD5 qw( md5_hex );
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

has 'reactor'  => ( is       => 'ro',
                    isa      => 'CodeRef',
                    required => 1,
                );

sub react {
    my ( $self, $data ) = @_;

    return unless $data;

    $data->{checksum}   = $self->checksum( $data );

    unless ( $data->{lastupdate} ) {
        $data->{lastupdate} = time;
    }

    unless ( $data->{plugin} ) {
        $data->{plugin}     = $self->{class};
    }

    $data->{key}        = $self->key;

    $data->{hostname}  = $self->hostname;

    $self->reactor->( $data );

    return $data;
}

sub checksum {
    my ( $self, $message ) = @_;

    return md5_hex( YAML::Dump $message );
}

1;
