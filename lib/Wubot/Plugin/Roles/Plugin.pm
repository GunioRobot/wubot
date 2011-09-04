package Wubot::Plugin::Roles::Plugin;
use Moose::Role;

# VERSION

use Wubot::Logger;

=head1 NAME

Wubot::Plugin::Roles::Plugin - a role that should be used by all wubot plugins


=head1 SYNOPSIS

    with 'Wubot::Plugin::Roles::Plugin';


=head1 DESCRIPTION

This role enforces that all wubot plugins (Wubot::Plugin::*) have some
basic required attributes, including a 'key', a 'class', and a
'logger'.  If a plugin is missing any of these attributes, serious
problems may result.

=cut

has 'key'      => ( is => 'ro',
                    isa => 'Str',
                    required => 1,
                );

has 'class'      => ( is => 'ro',
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


1;
