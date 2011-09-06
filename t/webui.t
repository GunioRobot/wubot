#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Mojo;

plan( skip_all => 'Author tests not required for installation' )
        unless ( $ENV{RELEASE_TESTING} );

use_ok 'App::Wubot::Web';

plan( 'no_plan' );

# Test
my $t = Test::Mojo->new('App::Wubot::Web');
$t->get_ok('/notify')->status_is(200)
  ->content_type_is('text/html;charset=UTF-8')
  ->content_like(qr/Wubot Notification/i);

