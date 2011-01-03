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

has 'count'    => ( is => 'rw',
                    isa => 'Num',
                    default => 0,
                );

has 'lastfetch' => ( is => 'rw',
                     isa => 'Num',
                     default => 0,
                 );

with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

    $self->logger->debug( "Checking remote queue on $config->{host}" );

    unless ( $self->machine ) {
        $self->logger->warn( "CONNECTING TO HOST: $config->{host}" );
        $self->machine( $self->create_machine( $config ) );
        $self->reactor->( { subject => "GRID::Machine connecting to $config->{host}" } );
        return;
    }

    my $count = 0;

  MESSAGE:
    for my $message ( 1 .. 100 ) {
        my $results = $self->machine->get_message( $config->{path} );

        if ( $results->{errmsg} ) {
            $self->reactor->( { subject => "ERROR: $results->{errmsg}" } );
            last MESSAGE;
        }

        last MESSAGE unless $results->{results}->[0];

        $self->reactor->( $results->{results}->[0] );

        $self->machine->processed_message();

        $cache->{lastfetch} = time;

        $count++;
    }

    if ( $count && $count > 10 ) {
        $self->logger->info( $self->key, ": fetched $count messages" );
    }

    if ( $cache->{lastfetch} + 300 < time ) {
        $self->reactor->( { subject => "ERROR: no messages fetched in more than 5 minutes" } );
    }

    return { cache => $cache };
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
                Log::Log4perl->easy_init($DEBUG);
                return 1;
             }
        );
        YAML::Dump $results;
        die $results->errmsg unless $results->ok;
    }

    {
        my $results = $machine->sub(
            get_message => q{
                my $path = $_[0];

                unless ( $main::messenger ) {
                    use Wubot::LocalMessageStore;
                    $main::messenger = Wubot::LocalMessageStore->new();
                }

                my ( $message, $callback ) = $main::messenger->get( $path );

                $main::callback = $callback;
                return $message;
            },
        );
        YAML::Dump $results;
        die $results->errmsg unless $results->ok;
    }

    {
        my $results = $machine->sub(
            processed_message => q{
                $main::callback->();
            },
        );
        YAML::Dump $results;
        die $results->errmsg unless $results->ok;
    }

    $machine->init();

    return $machine;
}

1;
