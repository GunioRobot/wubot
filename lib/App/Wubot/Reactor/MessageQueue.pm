package App::Wubot::Reactor::MessageQueue;
use Moose;

# VERSION

use YAML;

use App::Wubot::Logger;
use App::Wubot::LocalMessageStore;

has 'mailbox'   => ( is      => 'ro',
                     isa     => 'App::Wubot::LocalMessageStore',
                     lazy    => 1,
                     default => sub {
                         return App::Wubot::LocalMessageStore->new();
                     },
                 );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );


sub react {
    my ( $self, $message, $config ) = @_;

    $self->mailbox->store( $message, $config->{directory} );

    return $message;
}

1;

__END__

=head1 NAME

App::Wubot::Reactor::MessageQueue - store messages in a App::Wubot::LocalMessageStore queue

=head1 DESCRIPTION

TODO: More to come...


=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back
