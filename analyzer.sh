#!/usr/bin/env bash
#--------------------------------------------------------------------------------------------------
# Analyzer4ws
# Copyright (c) Marco Lovazzano
# Licensed under the GNU General Public License v3.0
# http://github.com/martcus
#--------------------------------------------------------------------------------------------------

ANALYZER4WS_APPNAME="analyze4ws"
ANALYZER4WS_VERSION="0.2.0"
ANALYZER4WS_BASENAME=$(basename "$0")

# IFS stands for "internal field separator". It is used by the shell to determine how to do word splitting, i. e. how to recognize word boundaries.
SAVEIFS=$IFS
IFS=$(echo -en "\n\b") # <-- change this as it depends on your app

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename "${__file}" .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this as it depends on your app

# Default options
_TABLEVIEW="N"
_LINES="10"

# internal function - print version
function _version() {
    echo -e ""
    echo -e "$(basename "$0") v$ANALYZER4WS_VERSION"
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
    echo -e "$(basename "$0") v$ANALYZER4WS_VERSION"
    echo -e "Analyzer for web services based on axis1"
    echo -e "Copyright (c) Marco Lovazzano"
    echo -e "Licensed under the GNU General Public License v3.0"
    echo -e "http://github.com/martcus"
    echo -e ""
    echo -e "Usage: $ANALYZER4WS_BASENAME [OPTIONS]"
    echo -e "      --help                     : Print this help"
    echo -e "      --version                  : Print version"
    echo -e " -f , --file [FILENAME]          : Set the filename to scan."
    echo -e " -l , --lines [FILENAME]         : Set the number of max lines to retrieve."
    echo -e " -d , --dateformat [DATE FORMAT] : Set the date format for requesttime and responsetime. Refer to date command (man date)."
    echo -e "                                 : Default value is: +%H:%M:%S"
    echo -e " -s , --service [SERVICE]        : Set the filter by <targetService>"
    echo -e " -o , --operation [OPERATION]    : Set the filter by <targetOperation>"
    echo -e " -t , --table                    : Diplay the output as a table"
    echo -e "      --orderby [FIELD}          : Specifies the field for which sorting is performed."
    echo -e "                                   The options are: requesttime, responsetime, exectime."
    echo -e "                                   Default value: exectime."
    echo -e ""
    echo -e "Exit status:"
    echo -e " 0  if OK,"
    echo -e " 1  if some problems (e.g., cannot access subdirectory)."
    echo -e ""
    exit 0
}

# internal function - print header
function _header {
    echo "#;messageId;targetService;targetOperation;exectime(ms);requestTime;responseTime"
}

# internal function - convert timestap to date.
# parameters:
# - timestamp
# - format date - Refer to date command (man date)
# usage: _convertDate 1571177907261 "+%Y-%m-%d %H:%M:%S"
function _convertDate {
    _convertedDate=$(date -d @$(($1/1000)) "$2")
}

OPTS=$(getopt -o :f:d:l:o:s:t --long "help,version,file:,dateformat:,lines:,operation:,service:,table,orderby:" -n $ANALYZER4WS_APPNAME -- "$@")
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
            _LINES="$2"
            shift 2;;
        # Set filter on targetService
        -s|--service)
            SERVICE="$2"
            shift 2;;
        # Set filter on targetOperation
        -o|--operation)
            OPERATION="$2"
            shift 2;;
        # Set filter on targetOperation
        -t|--table)
            _TABLEVIEW="Y"
            shift 1;;
        # Set the order
        --orderby)
            field="$2"
            if [ "$field" = "requesttime" ]; then
                _CMD_SORT_INDEX=6
            fi
            if [ "$field" = "responsetime" ]; then
                _CMD_SORT_INDEX=7
            fi
            if [ "$field" = "exectime" ]; then
                _CMD_SORT_INDEX=8
            fi
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

# Command Variables
_CMD_GREP="zgrep Response.*$SERVICE.*$OPERATION.*exectime $LOG_FILE"
_CMD_SED="sed 's/<!--type=// ; s/sessionId=// ; s/messageId=// ; s/targetService=// ; s/targetOperation=// ; s/requestTime=// ; s/responseTime=// ; s/;exectime=/;/ ; s/-->/;/'"
_CMD_SORT_INDEX=8
_CMD_SORT="sort -r -n -t\";\" -k$_CMD_SORT_INDEX"
_CMD_HEAD="head -$_LINES"
_CMD_TABLE="column -t -s ';'"

function _buildCmd() {
    _CMD=$_CMD_GREP" | "$_CMD_SED" | "$_CMD_SORT" | "$_CMD_HEAD
    # echo "DEBUG> "${_CMD}
}

COUNTER=1
_header > .temp
_buildCmd
for line in $(eval "$_CMD"); do

    _convertDate "$(echo "$line" | cut -d";" -f6)" $FORMAT_DATE
    requestTimeDate=$_convertedDate

    _convertDate "$(echo "$line" | cut -d";" -f7)" $FORMAT_DATE
    responseTimeDate=$_convertedDate

    echo $COUNTER";"$(echo "$line" | cut -d";" -f3,4,5,8)";""$requestTimeDate"";""$responseTimeDate" >> .temp
    COUNTER=$((COUNTER +1))
done

if [ "$_TABLEVIEW" = "Y" ]; then
    eval "$_CMD_TABLE" < .temp
else
    cat .temp
fi

rm .temp

# Restore IFS
IFS=$SAVEIFS
exit 0
