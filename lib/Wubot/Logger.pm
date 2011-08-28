package Wubot::Logger;
use strict;
use warnings;

# VERSION

use Log::Log4perl qw(:easy);

BEGIN {

    my $appender = "Log::Log4perl::Appender::ScreenColoredLevels";

    my $log_level = 'INFO';
    if ( $ENV{LOG_TRACE} || grep /\-trace/, @ARGV ) {
        $log_level = 'TRACE';
    }
    elsif ( $ENV{LOG_DEBUG} || grep /\-d(?:ebug)?/, @ARGV ) {
        $log_level = 'DEBUG';
    }
    elsif ( $ENV{LOG_VERBOSE} || grep /\-v(?:erbose)?/, @ARGV ) {
        $log_level = 'INFO';
    }
    elsif ( $0 =~ m|\.t$| ) {
        $log_level = 'FATAL';
        $appender = "Log::Log4perl::Appender::Screen";
    }
    else {
        $log_level = "WARN";
    }

    #warn "LOGGING INITIALIZED: $log_level\n";

    my $log_name = $0;
    $log_name =~ s|^.*\/||;

    my $conf = <<"END_SCREEN_CONF";
        log4perl.appender.Screen = $appender
        log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Screen.layout.ConversionPattern = %d> %m %n
        log4perl.appender.Screen.Threshold   = $log_level
        log4perl.appender.Screen.color.trace = blue
        log4perl.appender.Screen.color.debug = cyan
        log4perl.appender.Screen.color.info  = green
        log4perl.appender.Screen.color.warn  = magenta
        log4perl.appender.Screen.color.error = yellow
        log4perl.appender.Screen.color.fatal = red

END_SCREEN_CONF

my $log_conf = <<"END_LOG_CONF";

        log4perl.appender.Logfile = Log::Dispatch::FileRotate
        log4perl.appender.Logfile.filename    = $ENV{HOME}/logs/$log_name.log
        log4perl.appender.Logfile.max         = 10
        log4perl.appender.Logfile.mode        = append
        log4perl.appender.Logfile.DatePattern = yyyy-MM-dd
        log4perl.appender.Logfile.TZ          = PST
        log4perl.appender.Logfile.layout      = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Logfile.layout.ConversionPattern = %d %m %n
        log4perl.appender.Logfile.Threshold    = DEBUG

END_LOG_CONF

    if ( $log_name =~ m/^wubot\-(?:monitor|reactor)$/ ) {
        $conf = join("\n", "log4perl.category = TRACE, Screen, Logfile", $conf, $log_conf );
    }
    else {
        $conf = join("\n", "log4perl.category = TRACE, Screen", $conf );
    }

    Log::Log4perl->init(\$conf);

    my $logger = Log::Log4perl::get_logger( __PACKAGE__ );

    $logger->warn( ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" );
    $logger->warn( "Logging Initialized..." );

    $logger->trace( $conf );

}


1;
