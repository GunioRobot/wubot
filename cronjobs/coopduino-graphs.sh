#!/usr/local/bin/bash

date=`date`
date=${date//:/\\:}

/usr/local/bin/rrdtool graph /usr/home/wu/wubot/rrd/graphs/Coopduino.png \
    -c 'BACK#666666' -c 'CANVAS#111111' --width 500 --height 150 \
    --right-axis '1:0' --font WATERMARK:1:Times\
    'DEF:coop=/usr/home/wu/wubot/rrd/rrd/Coopduino-coop/Coopduino-coop.rrd:temp:AVERAGE' \
    'DEF:lab=/usr/home/wu/wubot/rrd/rrd/Coopduino-lab/Coopduino-lab.rrd:temp:AVERAGE' \
    'DEF:outside=/usr/home/wu/wubot/rrd/rrd/Coopduino-outside/Coopduino-outside.rrd:temp:AVERAGE' \
    'LINE1:coop#00FF00:coop' \
    'LINE1:lab#0000FF:lab' \
    'LINE1:outside#FF00FF:outside' \
    "COMMENT:RRD Last Updated\\: $date"

/usr/local/bin/rrdtool graph /usr/home/wu/wubot/rrd/graphs/Coopduino-week.png --start='-7d' \
    -c 'BACK#666666' -c 'CANVAS#111111' --width 300 --height 100 \
    --right-axis '1:0' --font WATERMARK:1:Times\
    'DEF:coop=/usr/home/wu/wubot/rrd/rrd/Coopduino-coop/Coopduino-coop.rrd:temp:AVERAGE' \
    'DEF:lab=/usr/home/wu/wubot/rrd/rrd/Coopduino-lab/Coopduino-lab.rrd:temp:AVERAGE' \
    'DEF:outside=/usr/home/wu/wubot/rrd/rrd/Coopduino-outside/Coopduino-outside.rrd:temp:AVERAGE' \
    'LINE1:coop#00FF00:coop' \
    'LINE1:lab#0000FF:lab' \
    'LINE1:outside#FF00FF:outside' \
    "COMMENT:RRD Last Updated\\: $date"

