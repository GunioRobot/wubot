package Wubot::Tail;
use Moose;

use Fcntl qw( SEEK_END SEEK_CUR SEEK_SET O_NONBLOCK O_RDONLY );

has 'path'      => ( is       => 'rw',
                     isa      => 'Str',
                     required => 1,
                 );

has 'callback'  => ( is       => 'rw',
                     isa      => 'CodeRef',
                 );

has 'reset_callback' => ( is => 'rw',
                          isa => 'CodeRef',
                      );

has 'tail_fh'   => ( is      => 'rw',
                     lazy    => 1,
                     default => sub {
                         return $_[0]->get_fh();
                     },
                 );

has 'lastread'  => ( is      => 'rw',
                     isa     => 'Num',
                 );

has 'refresh'   => ( is      => 'rw',
                     isa     => 'Num',
                     default => sub {
                         # default behavior is to recheck if file was
                         # renamed or truncated every time we go to
                         # check and don't find any new lines.
                         return 1;
                     }
                 );

has 'count'     => ( is      => 'rw',
                     isa     => 'Num',
                     default => 0,
                 );

has 'leftover'  => ( is      => 'rw',
                     isa     => 'Str',
                     default => '',
                 );

has 'position'  => ( is      => 'rw',
                     default => undef,
                 );

sub get_lines {
    my ( $self ) = @_;

    $self->count( $self->count + 1 );

    my $path = $self->path;

    unless ( -r $path ) {
        $self->reset_callback->( "path not readable: $path" );
        return;
    }

    my $fh = $self->tail_fh;

    my $mtime = ( stat $path )[9];

    if ( my $lines = $self->_get_lines_nonblock( $fh ) ) {
        return $lines;
    }

    return 0 unless $self->count % $self->refresh == 0;

    my $end_pos = sysseek( $fh, 0, SEEK_END);

    my $was_truncated = $end_pos < $self->position ? 1 : 0;
    my $was_renamed   = $self->lastread && $mtime > $self->lastread ? 1 : 0;

    if ( $was_truncated || $was_renamed ) {

        if ( $was_truncated ) {
            $self->reset_callback->( "file was truncated: $path" );
        }
        else {
            $self->reset_callback->( "file was renamed: $path" );
        }

        $self->position( 0 );
        $self->tail_fh( $self->get_fh() );
        $fh = $self->tail_fh;

        return $self->_get_lines_nonblock( $fh );
    }

    # file was not truncated, seek back to same spot
    sysseek( $fh, 0, $self->position);

    return 0;
}

sub get_fh {
    my ( $self ) = @_;

    my $path = $self->path;

    sysopen( my $fh, $path, O_NONBLOCK|O_RDONLY )
        or die "can't open $path: $!";

    my $position = $self->position;

    if ( defined $position ) {
        sysseek( $fh, $position, SEEK_SET );
    }
    else {
        sysseek( $fh, 0, SEEK_END );
    }

    return $fh;
}

# adapted from: http://www.perlmonks.org/?node_id=55241
sub _get_lines_nonblock {
  my ( $self, $fh ) = @_;

  my $timeout = 0;
  my $rfd = '';

  vec($rfd,fileno($fh),1) = 1;
  return unless select($rfd, undef, undef, $timeout)>=0;

  # I'm not sure the following is necessary?
  return unless vec($rfd,fileno($fh),1);

  my $buf = '';
  my $n = sysread($fh,$buf,1024*1024);

  # no lines read, check if file was truncated/renamed
  $self->position( sysseek( $fh, 0, SEEK_CUR) );

  # No new lines found
  return unless $n;

  $self->lastread( time );

  # Prepend the last unfinished line
  $buf = $self->leftover . $buf;

  # And save any newly unfinished lines
  $self->leftover( (substr($buf,-1) !~ /[\r\n]/ && $buf =~ s/([^\r\n]*)$//) ? $1 : '' );

  return unless $buf;

  my $count = 0;

  for my $line ( split( /\n/, $buf ) ) {
      chomp $line;
      next unless $line;

      $self->callback->( $line );
      $count++;
  }

  return $count;
}

1;
