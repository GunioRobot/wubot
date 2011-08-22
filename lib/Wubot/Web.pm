package Wubot::Web;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc" (this plugin requires Perl 5.10)
  $self->plugin('pod_renderer');

  # Routes
  my $r = $self->routes;

  # Normal route to controller
  $r->route('/notify')->to('notify#notify');
  $r->route('/tags')->to('notify#tags');

  $r->route('/tasks')->to('tasks#tasks');
  $r->route('/ical')->to('tasks#ical');
  $r->route('/open/org/(.file)/(.link)')->to('tasks#open');

  $r->route('/graphs')->to('graphs#graphs');

  $r->route('/rss/:mailbox')->to('rss#rss');
  $r->route('/atom/:mailbox')->to('rss#atom');

  $r->route('/tv/crew/(.first)/(.last)')->to('tv#crew');
  $r->route('/tv/program/(.program_id)')->to('tv#program');
  $r->route('/tv/seen/(.show_id)/(.episode_num)/(.seen)')->to('tv#seen');
  $r->route('/tv/station/hide/(.station_id)/(.hide)')->to('tv#hide');
  $r->route('/tv/score/(.show)/(.score)')->to('tv#score');
  $r->route('/tv/rt/(.program_id)')->to('tv#rt');
  $r->route('/tv/schedule/crew/(.first)/(.last)')->to('tv#schedule_crew');
  $r->route('/tv/schedule')->to('tv#schedule');
  $r->route('/tv/schedule/(.program_id)')->to('tv#schedule_program');
  $r->route('/tv/ical')->to('tv#ical');
  $r->route('/tv/oldschedule')->to('tv#oldschedule');
}
1;
