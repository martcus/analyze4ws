#!/usr/bin/env bash
#--------------------------------------------------------------------------------------------------
# Analyzer4ws
# Copyright (c) Marco Lovazzano
# Licensed under the GNU General Public License v3.0
# http://github.com/martcus
#--------------------------------------------------------------------------------------------------

ANALYZER4WS_APPNAME="analyze4ws"
ANALYZER4WS_VERSION="0.1.0"
ANALYZER4WS_BASENAME=$(basename "$0")

function _todo(){
    echo "guarda i commenti della funzione"
    # parametrizzare:
    # - targetService
    # - targetOperation
    # - capire se gestibiel il sort abilitato o no
    # -
}

function _version() {
    echo -e "$(basename $0) v$ANALYZER4WS_VERSION"
	exit 0
}

function _usage() {
    echo "_usage"
    # $0 file da analizzare
    # $1 quante righe estrarre
}

function _header {
    # echo "type;sessionId;messageId;targetService;targetOperation;requestTime;responseTime;exectime"
    echo "type;sessionId;messageId;targetService;targetOperation;exectime;requestTime;responseTime"
}

FILELOG=$1
MAXROW=$2
FORMAT_DATE=$3 #+%Y-%m-%d %H:%M:%S

greppone=$(zgrep exectime $FILELOG | sed 's/<!--type=// ; s/sessionId=// ; s/messageId=// ; s/targetService=// ; s/targetOperation=// ; s/requestTime=// ; s/responseTime=// ; s/;exectime=/;/' | sed 's/-->/;/' | cut -d";" -f1,2,3,4,5,6,7,8 | sort -r -n -t";" -k8 | head -$MAXROW)

_header
COUNTER=1
for linea in $greppone; do
    #6 e 7 son gli indici dei tmepi
    # date -d @1571296515.725 "+%Y-%m-%d %H:%M:%S"

    requestTimeMs=$(echo $linea | cut -d";" -f6)
    responseTimeMs=$(echo $linea | cut -d";" -f7)

    requestTimeDate=$(date -d @$((requestTimeMs/1000)) $FORMAT_DATE)
    responseTimeDate=$(date -d @$((responseTimeMs/1000)) $FORMAT_DATE)

    echo $COUNTER";"$(echo $linea | cut -d";" -f1,2,3,4,5,8)";"$requestTimeDate";"$responseTimeDate
    COUNTER=$[$COUNTER +1]
done

exit 0
