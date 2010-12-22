package Wubot::Plugin::RemoteQueue;
use Moose;

use GRID::Machine;
use Log::Log4perl;
use YAML;

has 'logger'    => ( is      => 'ro',
                     isa     => 'Log::Log4perl::Logger',
                     lazy    => 1,
                     default => sub {
                         return Log::Log4perl::get_logger( __PACKAGE__ );
                     },
                 );

has 'machine'   => ( is      => 'rw',
                     isa     => 'GRID::Machine',
                 );

has 'reactor'  => ( is => 'ro',
                    isa => 'CodeRef',
                    required => 1,
                );

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};

    unless ( $self->machine ) {
        $self->machine( $self->create_machine( $config ) );
        $self->reactor->( { subject => "GRID::Machine connecting to $config->{host}" } );
        return;
    }

  MESSAGE:
    for my $message ( 1 .. 10 ) {
        my $results = $self->machine->get_message( $config->{path} );

        next MESSAGE unless $results->{results}->[0];

        $self->reactor->( $results->{results}->[0] );

        $self->machine->processed_message();
    }

    return;
}

sub create_machine {
    my ( $self, $config ) = @_;

    my $machine = GRID::Machine->new( host => $config->{host},
                                      perl => $config->{perl},
                                  );

    $machine->modput( "Wubot::SQLite" );
    $machine->modput( "Wubot::LocalMessageStore" );

    {
        my $results = $machine->sub(
            init        => q{
                use Log::Log4perl qw(:easy);
                Log::Log4perl->easy_init($INFO);
                use Wubot::LocalMessageStore;
                $main::messenger = Wubot::LocalMessageStore->new();
             }
        );
        die $results->errmsg unless $results->ok;
    }

    {
        my $results = $machine->sub(
            get_message => q{
                my $path = $_[0];
                my ( $message, $callback ) = $main::messenger->get( $path );
                $main::callback = $callback;
                return $message;
            },
        );
        die $results->errmsg unless $results->ok;
    }

    {
        my $results = $machine->sub(
            processed_message => q{
                $main::callback->();
            },
        );
        die $results->errmsg unless $results->ok;
    }

    my $init_results = $machine->init();

    return $machine;
}

1;
