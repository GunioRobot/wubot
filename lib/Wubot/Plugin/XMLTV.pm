package Wubot::Plugin::XMLTV;
use Moose;

use Date::Manip;
use Log::Log4perl;
use POSIX qw(strftime);
use XML::Twig;
use YAML;

use Wubot::SQLite;
use Wubot::TimeLength;

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

        if ( $config->{grab} ) {
            my ( $mtime ) = ( stat( $xmlfile ) )[9];
            my $age       = time - $mtime;

            my $human_age = $self->timelength->get_human_readable( $age );
            $self->logger->info( $self->key, ": cache age: $human_age" );

            if ( $age > 60*60*20 ) {
                $self->logger->warn( "Grabbing XMLTV Data, cache is $human_age old" );
                system( "$config->{grab} > $xmlfile" );
            } else {
                $self->logger->info( "Not getting latest xmltv data - only $human_age old" );
            }
        }

        my $channels;

        $self->logger->warn( "Parsing XMLTV Data" );

        my $twig=XML::Twig->new(
            twig_handlers => 
                { channel     => sub {
                      my $id   = $_->att( 'id' );
                      my $info = $_->field( 'display-name' );

                      $info =~ m|^(\d+)\s(.*)$|;

                      $channels->{$id} = { channel => $1, name => $2 };

                  },
                  programme   => sub {
                      $count++;

                      my $program;
                      $program->{channel}     = $channels->{ $_->att( 'channel' ) }->{channel};
                      $program->{station}     = $channels->{ $_->att( 'channel' ) }->{name};

                      unless ( $config->{skip_stations}->{ $program->{station} } || $config->{skip_channels}->{ $program->{channel} } ) {

                          $program->{start}       = $_->att( 'start' );
                          $program->{end}         = $_->att( 'stop' );
                          $program->{title}       = $_->field( 'title' );


                          $program->{subtitle}    = $_->field( 'subtitle' ) || $_->field( 'sub-title' );

                          #print "$count: $program->{title} => $program->{subtitle}\n";

                          $program->{date}        = $_->field( 'date' );
                          $program->{desc}        = $_->field( 'desc' );

                          for my $child ( $_->find_by_tag_name( 'episode-num' ) ) {
                              if ( $child->att( 'system' ) eq "dd_progid" ) {
                                  $program->{dd_progid} = $child->text;

                                  $program->{show_id} = $program->{dd_progid};
                                  $program->{show_id} =~ s|\..*$||;

                              } elsif ( $child->att( 'system' ) eq "onscreen" ) {
                                  $program->{episode_num} = $child->text;
                              }
                          }

                          my @categories;
                          for my $child ( $_->find_by_tag_name( 'category' ) ) {
                              push @categories, $child->text;
                          }
                          $program->{categories} = join( ", ", @categories );

                          $program->{start_utime} = UnixDate( ParseDate( $program->{start} ), "%s" );

                          if ( $program->{end} ) {
                              $program->{end_utime}   = UnixDate( ParseDate( $program->{end} ), "%s" );
                              $program->{length} = $self->timelength->get_human_readable( $program->{end_utime} - $program->{start_utime} );
                          }

                          $program->{stars}      = $_->field( 'star-rating' );

                          for my $child ( $_->find_by_tag_name( 'rating' ) ) {
                              next unless $child->att( 'system' ) eq "MPAA" || $child->att( 'system' ) eq "VCHIP";
                              $program->{rating} = $child->text;
                          }

                          for my $child ( $_->find_by_tag_name( 'video' ) ) {
                              my $text = $child->text;
                              next if ( $text eq "no" || $text eq "yes" );
                              if ( $text eq "16:9HDTV" ) {
                                  $text = "HD";
                              }
                              $program->{video} = $text;
                          }

                          for my $child ( $_->find_by_tag_name( 'audio' ) ) {
                              $program->{audio} = $child->text;
                          }

                          if ( ! $_->find_by_tag_name( 'previously-shown' ) ) {
                              if ( $program->{subtitle} || $program->{episode_num} ) {
                                  $program->{fresh} = "NEW";
                              }
                          }

                          # todo: new
                          # todo: credits
                          # todo: subtitles

                          $program->{lastupdate} = time;
                          $sqlite->insert( $config->{tablename},
                                           $program,
                                           $config->{schema} );

                      }

                  },
              },
            pretty_print => 'indented',
        );

        $twig->parsefile( $xmlfile );

        $self->logger->warn( "Finished parsing XMLTV Data" );

        1;
    } or do {                   # catch

        $self->reactor->( { subject => "Error processing XMLTV Data: $@" } );

    };

    $self->reactor->( { subject => "Finished processing XMLTV Data: $count entries" } );
    exit 0;
}

1;
