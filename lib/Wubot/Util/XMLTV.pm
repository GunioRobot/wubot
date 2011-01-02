package Wubot::Util::XMLTV;
use Moose;

use Date::Manip;
use POSIX qw(strftime);
use XML::Twig;
use YAML;

use Wubot::Logger;
use Wubot::SQLite;
use Wubot::TimeLength;

has 'db' => ( is => 'ro',
              isa => 'Wubot::SQLite',
              lazy => 1,
              default => sub {
                  my $self = shift;
                  return Wubot::SQLite->new( { file => $self->dbfile } );
              },
          );

has 'dbfile' => ( is => 'ro',
                  isa => 'Str',
                  lazy => 1,
                  default => sub {
                      my $self = shift;
                      return $self->schemas->{files}->{tv};
                  },
              );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'schemas' => ( is => 'ro',
                   isa => 'HashRef',
                   lazy => 1,
                   default => sub {
                       return ( YAML::LoadFile( "config/schemas.yaml" ) );
                   },
               );

has 'timelength' => ( is => 'ro',
                      isa => 'Wubot::TimeLength',
                      lazy => 1,
                      default => sub {
                          return Wubot::TimeLength->new();
                      },
                  );

has 'score_colors' => ( is => 'ro',
                        isa => 'HashRef',
                        lazy => 1,
                        default => sub {
                            return { 0 => 'gray',
                                     1 => '#666699',
                                     2 => '#666699',
                                     3 => '#999900',
                                     4 => '#AA7700',
                                     5 => '#FF33FF',
                                 };

                        },
                    );



sub process_data {
    my ( $self, $xmlfile ) = @_;

    my $now = time;

    my $twig=XML::Twig->new(
        twig_handlers => 
            { station     => sub {

                  my $station = { station_id => $_->att( 'id' ),
                                  callsign   => $_->field( 'callSign' ),
                                  name       => $_->field( 'name' ),
                                  affiliate  => $_->field( 'affiliate' ),
                                  fccnumber  => $_->field( 'fccChannelNumber' ),
                                  lastupdate => $now,
                              };

                  #$self->logger->debug( "STATION: $station->{station_id} => $station->{callsign} => $station->{name}" );

                  $self->db->insert( 'station',
                                     $station,
                                     $self->schemas->{tv_station}
                                 );

              },
              lineup      => sub {

                  for my $child ( $_->find_by_tag_name( 'map' ) ) {

                      my $entry = { lineup_id  => $_->att('id'),
                                    channel    => $child->att('channel'),
                                    station_id => $child->att('station'),
                                    lastupdate => $now,
                                };

                      #$self->logger->debug( "LINEUP: $entry->{station_id} => $entry->{station_id} => $entry->{channel}" );

                      $self->db->insert( 'lineup',
                                         $entry,
                                         $self->schemas->{tv_lineup}
                                     );
                  }


              },
              schedule     => sub {

                  my $start_time = UnixDate( ParseDate( $_->att('time') ), "%s" );

                  my $entry = { program_id  => $_->att('program'),
                                station_id  => $_->att('station'),
                                start       => $start_time,
                                duration    => $_->att('duration' ),
                                new         => $_->att('new'),
                                cc          => $_->att('closeCaptioned'),
                                stereo      => $_->att('stereo'),
                                tv_rating   => $_->att('tvRating'),
                                dolby       => $_->att('dolby'),
                                hd          => $_->att('hdtv'),
                                lastupdate  => $now,
                            };

                  $self->db->insert( 'schedule',
                                     $entry,
                                     $self->schemas->{tv_schedule}
                                 );


              },
              program     => sub {

                  my $entry = { program_id  => $_->att('id'),
                                title       => $_->field('title'),
                                subtitle    => $_->field('subtitle'),
                                description => $_->field('description'),
                                show_type   => $_->field('showType'),
                                series_id   => $_->field('series'),
                                episode_id  => $_->field('syndicatedEpisodeNumber'),
                                date        => $_->field('originalAirDate'),
                                mpaa_rating => $_->field('mpaaRating'),
                                stars       => $_->field('starRating'),
                                runtime     => $_->field('runTime'),
                                year        => $_->field('year'),
                                color       => $_->field('colorCode'),
                                lastupdate  => $now,
                            };

                  $self->db->insert( 'program',
                                     $entry,
                                     $self->schemas->{tv_program}
                                 );


              },
              crew         => sub {

                  for my $child ( $_->find_by_tag_name( 'member' ) ) {

                      my $entry = { program_id    => $_->att( 'program' ),
                                    role          => $child->field( 'role' ),
                                    givenname     => $child->field( 'givenname' ),
                                    surname       => $child->field( 'surname' ),
                                    lastupdate    => $now,
                                };

                      $self->db->insert( 'crew',
                                         $entry,
                                         $self->schemas->{tv_crew}
                                     );

                  }
              },
              programGenre  => sub {

                  for my $child ( $_->find_by_tag_name( 'genre' ) ) {

                      my $entry = { program_id   => $_->att( 'program' ),
                                    genre        => $child->field( 'class' ),
                                    relevance    => $child->field( 'relevance' ),
                                    lastupdate   => $now,
                                };

                      $self->db->insert( 'genre',
                                         $entry,
                                         $self->schemas->{tv_genre}
                                     );
                  }

              },
          },
        pretty_print => 'indented',
    );

    $twig->parsefile( $xmlfile );

}

sub get_data {
    my ( $self, $table, $where, $key, $order ) = @_;

    my @data;

    my $fields = '*';
    if ( $key ) { $fields = $key }

    $self->db->select( { tablename => $table,
                         where     => $where,
                         fields    => $fields,
                         order     => $order,
                         callback  => sub {
                             my $entry = shift;

                             if ( $key ) {
                                 push @data, $entry->{ $key };
                             }
                             else {
                                 push @data, $entry;
                             }
                         },
                     } );

    return @data;

}

sub get_series_id {
    my ( $self, $name ) = @_;

    my %ids;

    $self->db->select( { tablename => 'program',
                         where     => { title => $name },
                         fields    => 'series_id',
                         callback  => sub {
                             my $entry = shift;
                             $ids{ $entry->{series_id} }++;
                         },
                     } );

    return sort keys %ids;

}

sub get_program_id {
    my ( $self, $name ) = @_;

    my %ids;

    $self->db->select( { tablename => 'program',
                         fields    => 'program_id',
                         where     => { title => $name },
                         callback  => sub {
                             my $entry = shift;
                             $ids{ $entry->{program_id} }++;
                         },
                     } );

    return sort keys %ids;

}

sub get_program_details {
    my ( $self, $program_id ) = @_;

    my @details;

    $self->db->select( { tablename => 'program',
                         where     => { program_id => $program_id },
                         callback  => sub {
                             my $entry = shift;
                             push @details, $entry;
                         },
                     } );

    return @details;
}

sub get_station {
    my ( $self, $where ) = @_;

    my @details;

    $self->db->select( { tablename => 'station',
                         where     => $where,
                         callback  => sub {
                             my $entry = shift;
                             push @details, $entry;
                         },
                     } );

    return @details;
}


sub get_program_crew {
    my ( $self, $program_id ) = @_;

    return $self->get_data( 'crew', { program_id => $program_id } );

}

sub get_roles {
    my ( $self, $first, $last ) = @_;

    my @programs;

    for my $program ( $self->get_data( 'crew', { givenname => $first, surname => $last }, 'program_id' ) ) {

        push @programs, $program;
    }

    return sort @programs;
}

sub get_program_genres {
    my ( $self, $program_id ) = @_;

    return $self->get_data( 'genre', { program_id => $program_id }, 'genre', 'relevance' );
}

sub get_channel {
    my ( $self, $station_id ) = @_;

    return ( $self->get_data( 'lineup', { station_id => $station_id }, 'channel' ) )[0];
}

sub get_station_id {
    my ( $self, $channel ) = @_;

    my ( $station_id ) = $self->get_data( 'lineup', { channel => $channel }, 'station_id' );

    return $station_id;
}

sub hide_station {
    my ( $self, $station_id, $hide ) = @_;

    $self->db->update( 'station',
                       { hide => $hide, lastupdate => time },
                       { station_id => $station_id },
                       $self->schemas->{tv_station}
                   );
}

sub is_station_hidden {
    my ( $self, $station_id ) = @_;

    my ( $hidden_flag ) = $self->get_data( 'station', { station_id => $station_id }, 'hide' );

    return $hidden_flag;
}

sub set_score {
    my ( $self, $program_id, $score ) = @_;

    $self->db->insert_or_update( 'score',
                                 { score => $score, program_id => $program_id, lastupdate => time },
                                 { program_id => $program_id },
                                 $self->schemas->{tv_score}
                             );
}

sub get_program_color {
    my ( $self, $program_id, $score ) = @_;

    unless ( $score ) {
        $score = $self->get_score( $program_id );
    }

    return $self->score_colors->{ $score || 0 };

}

sub get_score {
    my ( $self, $program_id ) = @_;

    my $series_id = $program_id;
    $series_id =~ s|....$|0000|;

    my $score;

    eval {
        ( $score ) = $self->get_data( 'score',
                                      [ { program_id => $program_id },
                                        { program_id => $series_id  },
                                    ],
                                      'score'
                                  );
    };

    return $score;
}

sub get_schedule {
    my ( $self, $options ) = @_;

    my $where;
    if ( $options->{start} ) {

        my $seconds = $self->timelength->get_seconds( $options->{start} );

        $where->{start} = { '>', time + $seconds };
    }
    else {
        $where->{start} = { '>', time };
    }

    if ( $options->{channel} ) {
        ( $where->{station_id} ) = $self->get_station_id( $options->{channel} );
    }

    if ( $options->{program_id} ) {
        $where->{program_id} = $options->{program_id};
    }

    my @entries;
    my $count = 0;

    $self->db->select( { tablename => 'schedule',
                         where     => $where,
                         limit     => $options->{limit} || 100,
                         order     => 'start',
                         callback  => sub {
                             my $entry = shift;

                             $count++;

                             my ( $station_data ) = $self->get_station( { station_id => $entry->{station_id} } );
                             return if $station_data->{hide};
                             for my $key ( keys %{ $station_data } ) {
                                 $entry->{ "channel_$key" } = $station_data->{ $key };
                             }

                             my ( $program_data ) = $self->get_program_details( $entry->{program_id} );
                             return if $program_data->{hide};
                             for my $key ( keys %{ $program_data } ) {
                                 $entry->{ $key } = $program_data->{ $key };
                             }

                             $entry->{channel} = $self->get_channel( $station_data->{station_id} );

                             $entry->{score} = $self->get_score( $entry->{program_id} );

                             if ( $entry->{score} && ! $options->{all} ) {

                                 if ( $options->{score} ) {
                                     return unless $entry->{score} >= $options->{score};
                                 }
                                 else {
                                     # default min score, if a score is not assigned
                                     return unless $entry->{score} >= 3;
                                 }
                             }
                             else {
                                 return if $options->{score};
                             }

                             $entry->{color} = $self->get_program_color( $entry->{program_id}, $entry->{score} );

                             $entry->{start_time}  = strftime( "%a %l:%M%p", localtime( $entry->{start} ) );

                             $entry->{runtime}  = $entry->{duration} || $entry->{runtime};
                             $entry->{runtime}  =~ s|^PT0||;
                             $entry->{runtime}  =~ s|^0H||;
                             $entry->{runtime}  = lc( $entry->{runtime} );
                             $entry->{duration} = $entry->{runtime};

                             $entry->{count} = $count;

                             push @entries, $entry;
                         },
                     } );

    return @entries;
}

1;
