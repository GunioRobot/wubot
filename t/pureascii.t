#!perl

use Test::More;
eval "use Test::PureASCII";
plan skip_all => "Test::PureASCII required" if $@;

Test::PureASCII::all_perl_files_are_pure_ascii();
