package Wubot::Logger;
use strict;
use warnings;

# VERSION

use Log::Log4perl qw(:easy);

BEGIN {

    my $log_level = $ENV{LOG_TRACE} ? 'TRACE' : $ENV{LOG_DEBUG} ? 'DEBUG' : 'INFO';

    my $log_name = $0;
    $log_name =~ s|^.*\/||;

    Log::Log4perl->init(\ <<"EOT");
        log4perl.category = TRACE, Screen, Logfile
        log4perl.appender.Screen = Log::Log4perl::Appender::ScreenColoredLevels
        log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Screen.layout.ConversionPattern = %d> %m %n
        log4perl.appender.Screen.Threshold   = $log_level
        log4perl.appender.Screen.color.trace = cyan
        log4perl.appender.Screen.color.debug = blue
        log4perl.appender.Screen.color.info  = green
        log4perl.appender.Screen.color.warn  = magenta
        log4perl.appender.Screen.color.error = yellow
        log4perl.appender.Screen.color.fatal = red

        log4perl.appender.Logfile = Log::Dispatch::FileRotate
        log4perl.appender.Logfile.filename    = $ENV{HOME}/logs/$log_name.log
        log4perl.appender.Logfile.max         = 10
        log4perl.appender.Logfile.mode        = append
        log4perl.appender.Logfile.DatePattern = yyyy-MM-dd
        log4perl.appender.Logfile.TZ          = PST
        log4perl.appender.Logfile.layout      = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Logfile.layout.ConversionPattern = %d %m %n
        log4perl.appender.Logfile.Threshold    = DEBUG

EOT

    my $logger = Log::Log4perl::get_logger( __PACKAGE__ );

    $logger->warn( ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" );
    $logger->warn( "Logging Initialized..." );

}


1;
