#!/usr/bin/env bash
#--------------------------------------------------------------------------------------------------
# Analyzer4ws
# Copyright (c) Marco Lovazzano
# Licensed under the GNU General Public License v3.0
# http://github.com/martcus
#--------------------------------------------------------------------------------------------------

ANALYZER4WS_APPNAME="analyze4ws"
ANALYZER4WS_VERSION="0.1.1"
ANALYZER4WS_BASENAME=$(basename "$0")

# internal function - print version
function _version() {
    echo -e ""
    echo -e "$(basename $0) v$ANALYZER4WS_VERSION"
    echo -e "Analyzer for web services based on axis1"
    echo -e "Copyright (c) Marco Lovazzano"
    echo -e "Licensed under the GNU General Public License v3.0"
    echo -e "http://github.com/martcus"
    echo -e ""
    exit 0
}

# internal function - help
function _usage() {
    echo -e ""
    echo -e "$(basename $0) v$ANALYZER4WS_VERSION"
    echo -e "Analyzer for web services based on axis1"
    echo -e "Copyright (c) Marco Lovazzano"
    echo -e "Licensed under the GNU General Public License v3.0"
    echo -e "http://github.com/martcus"
    echo -e ""
    echo -e "Usage: $ANALYZER4WS_BASENAME [OPTIONS]"
    echo -e "      --help                     : Print this help"
    echo -e "      --version                  : Print version"
    echo -e " -f , --file [filename]          : Set the filename to scan."
    echo -e " -l , --lines [filename]         : Set the number of max lines to retrieve."
    echo -e " -d , --dateformat [DATE FORMAT] : Set the date format. Refer to date command (man date)."
    echo -e " -s , --service [SERVICE]        : Set the filter by <targetService>"
    echo -e " -o , --operation [OPERATION]    : Set the filter by <targetOperation>"
    echo -e ""
    echo -e "Exit status:"
    echo -e " 0  if OK,"
    echo -e " 1  if some problems (e.g., cannot access subdirectory)."
    echo -e ""
    exit 0
}

# internal function - print header
function _header {
    echo "type;sessionId;messageId;targetService;targetOperation;exectime;requestTime;responseTime"
}

# internal function - convert timestap to date.
# parameters:
# - timestamp
# - format date - Refer to date command (man date)
# usage: _convertDate 1571177907261 "+%Y-%m-%d %H:%M:%S"
function _convertDate {
    _convertedDate=$(date -d @$(($1/1000)) $2)
}

OPTS=$(getopt -o :f:d:l:o:s: --long "help,version,file:,dateformat:,lines:,operation:,service:" -n $ANALYZER4WS_APPNAME -- "$@")
OPTS_EXITCODE=$?
# bad arguments, something has gone wrong with the getopt command.
if [ $OPTS_EXITCODE -ne 0 ]; then
    # Option not allowed
    echo -e "Error: '$ANALYZER4WS_BASENAME' invalid option '$1'."
    echo -e "Try '$ANALYZER4WS_BASENAME --help' for more information."
    exit 1
fi

# a little magic, necessary when using getopt.
eval set -- "$OPTS"

while true; do
    case "$1" in
        --help)
            _usage
            exit 0;;
        --version)
            _version
            exit 0;;
        # Date format
        -d|--dateformat)
            date "$2" > /dev/null 2>&1
            DATE_EXITCODE=$?
            if [ ! $DATE_EXITCODE -eq 0 ]; then
                echo "Error: '$0' '-d $2' is not a valid date format. Refer to date command (man date)"
                exit 1
            fi
            FORMAT_DATE=$2
            shift 2;;
        # Set filename
        -f|--file)
            LOG_FILE="$2"
            shift 2;;
        # Set lines
        -l|--lines)
            LINES="$2"
            shift 2;;
        # Set filter on targetService
        -s|--service)
            SERVICE="$2"
            shift 2;;
        # Set filter on targetOperation
        -o|--operation)
            OPERATION="$2"
            shift 2;;
        --)
            shift
            break
			;;
    esac
done

if [ -z "$FORMAT_DATE" ]; then
    FORMAT_DATE=${FORMAT_DATE:="+%H:%M:%S"}
fi

if [ -z "$LOG_FILE" ]; then
    echo -e "Error: '$0' enter file name."
    echo -e "Try '$ANALYZER4WS_BASENAME --help' for more information."
    exit 1
fi

if [ -z "$LINES" ]; then
    echo -e "Error: '$0' is necessary to enter the number of lines"
    echo -e "Try '$ANALYZER4WS_BASENAME --help' for more information."
    exit 1
fi

_GREP=$(zgrep $SERVICE.*$OPERATION.*exectime $LOG_FILE | sed 's/<!--type=// ; s/sessionId=// ; s/messageId=// ; s/targetService=// ; s/targetOperation=// ; s/requestTime=// ; s/responseTime=// ; s/;exectime=/;/ ; s/-->/;/' | sort -r -n -t";" -k8 | head -$LINES)

COUNTER=1
_header
for line in $_GREP; do
    _convertDate $(echo $line | cut -d";" -f6) $FORMAT_DATE
    requestTimeDate=$_convertedDate

    _convertDate $(echo $line | cut -d";" -f7) $FORMAT_DATE
    responseTimeDate=$_convertedDate

    echo $COUNTER";"$(echo $line | cut -d";" -f1,2,3,4,5,8)";"$requestTimeDate";"$responseTimeDate

    COUNTER=$[$COUNTER +1]
done

exit 0
