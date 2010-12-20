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

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};

    my @react;

    unless ( $self->machine ) {
        push @react, { subject => "GRID::Machine connecting to $config->{host}" };
        $self->machine( $self->create_machine( $config ) );
    }

    my $results = $self->machine->get_message( $config->{path} );

    if ( $results->{results} ) {
        push @react, @{ $results->{results} };
    }

    if ( scalar @react ) {
        return { react => \@react };
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

    my $results1 = $machine->sub(
        init        => q{
            use Log::Log4perl qw(:easy);
            Log::Log4perl->easy_init($INFO);
            use Wubot::LocalMessageStore;
            $main::messenger = Wubot::LocalMessageStore->new();
         }
    );
    die $results1->errmsg unless $results1->ok;

    my $results2 = $machine->sub(
        get_message => q{
            my $path = $_[0];
            my $message = $main::messenger->get( $path );
            return $message;
        },
    );
    die $results2->errmsg unless $results2->ok;

    my $init_results = $machine->init();

    return $machine;
}

1;
