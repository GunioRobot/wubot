package Wubot::Plugin::XMLTV;
use Moose;

use Date::Manip;
use Log::Log4perl;
use YAML;

use Wubot::SQLite;
use Wubot::TimeLength;
use Wubot::Util::XMLTV;

has 'reactor'  => ( is => 'ro',
                    isa => 'CodeRef',
                    required => 1,
                );


has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
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

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    my $xmlfile = $config->{xmlfile};

    my $sqlite = Wubot::SQLite->new( { file => $config->{dbfile} } );

    my $pid = fork();
    if ( $pid ) {
        # parent process
        return { cache => { pid => $pid },
                 react => { subject => "launched child pid $pid" }
             };
    }

    my $count = 0;

    # perform the check, catch any exceptions
    eval {                          # try

        $self->logger->warn( "Downloading and parsing XMLTV Data" );

        my $tv = Wubot::Util::XMLTV->new();
        $tv->fetch_process_data( $xmlfile );

        $self->logger->warn( "Finished parsing XMLTV Data" );

        1;
    } or do {                   # catch

        $self->reactor->( { subject => "Error processing XMLTV Data: $@" } );

    };

    $self->reactor->( { subject => "Finished processing XMLTV Data: $count entries" } );
    exit 0;
}

1;
