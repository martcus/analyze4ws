#!/usr/bin/env bash
#--------------------------------------------------------------------------------------------------
# Analyzer4ws
# Copyright (c) Marco Lovazzano
# Licensed under the GNU General Public License v3.0
# http://github.com/martcus
#--------------------------------------------------------------------------------------------------

readonly ANALYZER4WS_APPNAME="analyze4ws"
readonly ANALYZER4WS_VERSION="0.2.0"
readonly ANALYZER4WS_BASENAME=$(basename "$0")

# IFS stands for "internal field separator". It is used by the shell to determine how to do word splitting, i. e. how to recognize word boundaries.
readonly SAVEIFS=$IFS
IFS=$(echo -en "\n\b") # <-- change this as it depends on your app

# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset
# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail
# Turn on traces, useful while debugging but commented out by default
# set -o xtrace

# Set magic variables for current file & dir
readonly __dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly __file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
readonly __base="$(basename "${__file}" .sh)"
readonly __root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this as it depends on your app

# Default options
TABLE_VIEW="N"
LINES="10"
FORMAT_DATE="+%H:%M:%S"
SERVICE=""
OPERATION=""
TEMP_FILE=.temp.$(date +"%Y%m%d.%H%M%S.%5N")
LOG_FILE=""
SORT_INDEX=8

_CMD_TABLE="column -t -s ';'"

function debug() {
    echo "DEBUG> $1"
}

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
    echo -e "      --orderby [FIELD]          : Specifies the field for which sorting is performed."
    echo -e "                                   The options are: requesttime, responsetime, exectime."
    echo -e "                                   Default value: exectime."
    echo -e ""
    echo -e "Exit status:"
    echo -e " 0  if OK,"
    echo -e " 1  if some problems (e.g., cannot access subdirectory)."
    echo -e ""
    exit 0
}

# OPTS
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
        -d|--dateformat) # Date format
            date "$2" > /dev/null 2>&1
            DATE_EXITCODE=$?
            if [ ! $DATE_EXITCODE -eq 0 ]; then
                echo "Error: '$0' '-d $2' is not a valid date format. Refer to date command (man date)"
                exit 1
            fi
            FORMAT_DATE=$2
            shift 2;;
        -f|--file) # Set filename
            LOG_FILE="$2"
            shift 2;;
        -l|--lines) # Set lines
            LINES="$2"
            shift 2;;
        -s|--service) # Set filter on targetService
            SERVICE="$2"
            shift 2;;
        -o|--operation) # Set filter on targetOperation
            OPERATION="$2"
            shift 2;;
        -t|--table) # Set filter on targetOperation
            TABLE_VIEW="Y"
            shift 1;;
        --orderby) # Set the order field
            field="$2"
            if [ "$field" = "requesttime" ]; then
                SORT_INDEX=6
            fi
            if [ "$field" = "responsetime" ]; then
                SORT_INDEX=7
            fi
            if [ "$field" = "exectime" ]; then
                SORT_INDEX=8
            fi
            shift 2;;
        --)
            shift
            break
            ;;
    esac
done

# print header
function _header {
    echo "#;messageId;targetService;targetOperation;exectime(ms);requestTime;responseTime"
}

# convert timestap to date.
# parameters:
# 1- timestamp
# 2- format date - Refer to date command (man date)
# usage: _convertDate 1571177907261 "+%Y-%m-%d %H:%M:%S"
function _convertDate {
    _convertedDate=$(date -d @$(($1/1000)) "$2")
}

# build command
function _buildCmd() {
    # Command Variables
    local _CMD_GREP="zgrep Response.*$SERVICE.*$OPERATION.*exectime $LOG_FILE"
    local _CMD_SED="sed 's/<!--type=// ; s/sessionId=// ; s/messageId=// ; s/targetService=// ; s/targetOperation=// ; s/requestTime=// ; s/responseTime=// ; s/;exectime=/;/ ; s/-->/;/'"
    local _CMD_SORT="sort -r -n -t\";\" -k$SORT_INDEX"
    local _CMD_HEAD="head -$LINES"

    _CMD=$_CMD_GREP" | "$_CMD_SED" | "$_CMD_SORT" | "$_CMD_HEAD
    # debug ${_CMD}
}

# main functions
function main() {
    if [ -z "$LOG_FILE" ]; then
        echo -e "Error: '$0' enter file name."
        echo -e "Try '$ANALYZER4WS_BASENAME --help' for more information."
        exit 1
    fi

    COUNTER=1
    _header > $TEMP_FILE
    _buildCmd
    for line in $(eval "$_CMD"); do

        _convertDate "$(echo "$line" | cut -d";" -f6)" $FORMAT_DATE
        requestTimeDate=$_convertedDate

        _convertDate "$(echo "$line" | cut -d";" -f7)" $FORMAT_DATE
        responseTimeDate=$_convertedDate

        echo $COUNTER";"$(echo "$line" | cut -d";" -f3,4,5,8)";""$requestTimeDate"";""$responseTimeDate" >> $TEMP_FILE
        COUNTER=$((COUNTER +1))
    done

    if [ "$TABLE_VIEW" = "Y" ]; then
        eval "$_CMD_TABLE" < $TEMP_FILE
    else
        cat $TEMP_FILE
    fi

    rm $TEMP_FILE
}

main

# Restore IFS
IFS=$SAVEIFS
exit 0

# groupby and count
# zgrep exectime logfile.log | sed 's/<!--type=// ; s/sessionId=// ; s/messageId=// ; s/targetService=// ; s/targetOperation=// ; s/requestTime=// ; s/responseTime=// ; s/;exectime=/;/ ; s/-->/;/' | cut -d";" -f4,5 | sort | uniq -c | sort -nr | column -t -s ';'
