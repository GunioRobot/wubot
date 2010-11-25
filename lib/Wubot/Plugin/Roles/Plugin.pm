package Wubot::Plugin::Roles::Plugin;
use Moose::Role;

use Log::Log4perl;

has 'key'      => ( is => 'ro',
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