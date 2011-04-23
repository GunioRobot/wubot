package Wubot::Plugin::RemoteQueue;
use Moose;

# VERSION

use GRID::Machine;
use Log::Log4perl;
use YAML;

use Wubot::TimeLength;

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

has 'lastfetch' => ( is => 'rw',
                     isa => 'Num',
                     default => 0,
                 );

has 'timelength' => ( is => 'ro',
                      isa => 'Wubot::TimeLength',
                      lazy => 1,
                      default => sub {
                          return Wubot::TimeLength->new();
                      },
                  );


with 'Wubot::Plugin::Roles::Cache';
with 'Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

    $cache->{check_count}++;

    $self->logger->debug( "Checking remote queue on $config->{host}" );

    unless ( $self->machine ) {
        $self->logger->warn( "CONNECTING TO HOST: $config->{host}" );
        $self->machine( $self->create_machine( $config ) );
        $self->reactor->( { subject => "GRID::Machine connecting to $config->{host}" } );
        return {};
    }

    my $count = 0;

  MESSAGE:
    for my $message ( 1 .. 50 ) {
        my $results = $self->machine->get_message( $config->{path} );

        if ( $results->{errmsg} ) {
            $self->reactor->( { subject => "ERROR: $results->{errmsg}" } );
            last MESSAGE;
        }

        last MESSAGE unless $results->{results}->[0];

        if ( ref $results->{results}->[0] eq "HASH" ) {
            $self->reactor->( $results->{results}->[0] );
            $self->machine->processed_message();
        }
        else {
            warn "GRID::Machine got unexpected result: ", YAML::Dump $results;
        }

        $cache->{lastfetch} = time;

        $count++;
    }

    if ( $count && $count > 10 ) {
        $self->logger->info( $self->key, ": fetched $count messages" );
    }

    my $now = time;
    if ( $cache->{lastfetch} + 300 < $now && $cache->{check_count} % 10 == 0 ) {
        my $time = $self->timelength->get_human_readable( $now - $cache->{lastfetch} );
        $self->reactor->( { subject => "ERROR: no messages fetched in $time" } );
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
                return { subject => 'initialized' };
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
