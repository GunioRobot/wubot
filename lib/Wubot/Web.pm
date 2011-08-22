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
  $r->route('/open/org/(.file)/(.link)')->to('tasks#open');

  $r->route('/graphs')->to('graphs#graphs');

  $r->route('/rss/:mailbox')->to('rss#rss');
  $r->route('/atom/:mailbox')->to('rss#atom');
}

1;
