use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Wubot',
    AUTHOR              => 'Alex White <VVu@geekfarm.org>',
    VERSION_FROM        => 'lib/Wubot.pm',
    ABSTRACT_FROM       => 'lib/Wubot.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Wubot-Monitor-*' },
);
