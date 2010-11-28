use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Wubot',
    AUTHOR              => 'Alex White <VVu@geekfarm.org>',
    VERSION_FROM        => 'lib/Wubot.pm',
    ABSTRACT_FROM       => 'lib/Wubot.pm',
    PL_FILES            => {},

    EXE_FILES           => [ qw[ bin/wubot-monitor
                           ] ],

    PREREQ_PM => {
        'DBD::Pg'          => 0,
        'DBI'              => 0,
        'Devel::Size'      => 0,
        'File::Sync'       => 0,
        'File::Tail'       => 0,
        'File::chdir'      => 0,
        'Growl::Tiny'      => 0,
        'LWP::UserAgent'   => 0,
        'Log::Log4perl'    => 0,
        'MIME::Entity'     => 0,
        'MIME::Parser'     => 0,
        'Mail::MboxParser' => 0,
        'Maildir::Lite'    => 0,
        'Moose'            => 0,
        'Moose::Role'      => 0,
        'SQL::Abstract'    => 0,
        'Test::More'       => 0,
        'XML::Feed'        => 0,
        'YAML'             => 0,
    },

    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Wubot-Monitor-*' },
);
