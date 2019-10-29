#!/usr/bin/env bash
#--------------------------------------------------------------------------------------------------
# Analyzer4ws
# Copyright (c) Marco Lovazzano
# Licensed under the GNU General Public License v3.0
# http://github.com/martcus
#--------------------------------------------------------------------------------------------------

readonly ANALYZER4WS_APPNAME="analyze4ws"
readonly ANALYZER4WS_VERSION="0.2.1"
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

# Variable
analyzer4ws_debug=""
analyzer4ws_logfile=""
analyzer4ws_tempfile=""
analyzer4ws_filter_service=""
analyzer4ws_filter_operation=""
analyzer4ws_filter_lines=""
analyzer4ws_filter_orderby=""
analyzer4ws_format_table=""
analyzer4ws_format_date=""

analyzer4ws_cfg_file=""
analyzer4ws_cfg_file_default="defaults.yml"
analyzer4ws_result_count=0

# print debug message
# parameters:
# 1- message to echo
# usage: _debug "Hello, World!"
function _debug() {
    if [ "$analyzer4ws_debug" = "Y" ]; then
        echo "DEBUG> $1"
    fi
}

# print version
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

# print help
function _help() {
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
    echo -e " -c , --config [FILENAME]        : Use a yaml config file. This option override any inline parameters."
    echo -e ""
    echo -e "Exit status:"
    echo -e " 0  if OK,"
    echo -e " 1  if some problems (e.g., cannot access subdirectory)."
    echo -e ""
    exit 0
}

# parse yaml config file
# parameters:
# @parameter $1 file yaml
# @parameter $2 prefix for config variiables
function parse_yaml {
    local file_yaml=${1:-}
    local prefix=${2:-}
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')

    sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" $file_yaml |
    awk -F$fs '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) { if (i > indent) { delete vname[i] } }
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) { vn=(vn)(vname[i])("_") }
            printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
        }
    }'
}

# OPTS
OPTS=$(getopt -o :f:d:l:o:s:t:c: --long "help,version,file:,dateformat:,lines:,operation:,service:,table,orderby:,config:" -n $ANALYZER4WS_APPNAME -- "$@")
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
            _help
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
            analyzer4ws_format_date=$2
            shift 2;;
        -f|--file) # Set filename
            analyzer4ws_logfile="$2"
            shift 2;;
        -l|--lines) # Set lines
            analyzer4ws_filter_lines="$2"
            shift 2;;
        -s|--service) # Set filter on targetService
            analyzer4ws_filter_service="$2"
            shift 2;;
        -o|--operation) # Set filter on targetOperation
            analyzer4ws_filter_operation="$2"
            shift 2;;
        -t|--table) # Set filter on targetOperation
            analyzer4ws_format_table="Y"
            shift 1;;
        --orderby) # Set the order field
            analyzer4ws_filter_orderby="$2"
            shift 2;;
        -c|--config)
            analyzer4ws_cfg_file="$2"
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

# convert timestap (in ms) to date.
# parameters:
# @parameter $1- timestamp
# @parameter $2- format date - Refer to date command (man date)
# usage: _convertDate 1571177907261 "+%Y-%m-%d %H:%M:%S"
function _convertDate {
    _convertedDate=$(date -d @$(($1/1000)) "$2")
}

# build command
function _buildCmd() {
    # sort index
    if [ "$analyzer4ws_filter_orderby" = "requesttime" ]; then
        sort_index=6
    elif [ "$analyzer4ws_filter_orderby" = "responsetime" ]; then
        sort_index=7
    elif [ "$analyzer4ws_filter_orderby" = "exectime" ]; then
        sort_index=8
    fi

    # Command Variables
    local _CMD_GREP="zgrep Response.*$analyzer4ws_filter_service.*$analyzer4ws_filter_operation.*exectime $analyzer4ws_logfile"
    local _CMD_CUT_SINGLEROW="cut -d\"-\" -f3"
    local _CMD_SED="sed 's/type=// ; s/sessionId=// ; s/messageId=// ; s/targetService=// ; s/targetOperation=// ; s/requestTime=// ; s/responseTime=// ; s/;exectime=/;/ ; s/-->/;/'"
    local _CMD_SORT="sort -r -n -t\";\" -k$sort_index"
    local _CMD_HEAD="head -$analyzer4ws_filter_lines"

    _CMD=$_CMD_GREP" | "$_CMD_CUT_SINGLEROW" | "$_CMD_SED" | "$_CMD_SORT" | "$_CMD_HEAD
    _debug ${_CMD}
}

# check minimal requirements to execute the script
function check_requirements() {
    if [ -z "$analyzer4ws_logfile" ]; then
        echo -e "Error: '$0' enter file name."
        echo -e "Try '$ANALYZER4WS_BASENAME --help' for more information."
        exit 1
    fi

    if [ ! "$analyzer4ws_filter_orderby" = "" ] && ([ ! "$analyzer4ws_filter_orderby" = "requesttime" ] ||  [!  "$analyzer4ws_filter_orderby" = "responsetime" ] || [ "$analyzer4ws_filter_orderby" = "exectime" ]); then
        echo -e "Error: '$0' enter a valid orderby option."
        echo -e "Try '$ANALYZER4WS_BASENAME --help' for more information."
        exit 1
    fi
}

# load configurazione from yaml file
function load_cfg() {
    time_init=$(date +%s%N | cut -b1-13)
    eval $(parse_yaml $analyzer4ws_cfg_file_default)
    if [ ! -z "$analyzer4ws_cfg_file" ]; then
        eval $(parse_yaml $analyzer4ws_cfg_file)
    fi
    time_end=$(date +%s%N | cut -b1-13)
    _debug "Config loaded in "$(($time_end-$time_init))"ms"
}

# analyze function
function analyze() {
    _buildCmd

    for line in $(eval "$_CMD"); do
        if [[ analyzer4ws_result_count -eq 0 ]]; then
            _header > $analyzer4ws_tempfile
        fi
        analyzer4ws_result_count=$((analyzer4ws_result_count +1))

        _convertDate "$(echo "$line" | cut -d";" -f6)" $analyzer4ws_format_date
        requestTimeDate=$_convertedDate

        _convertDate "$(echo "$line" | cut -d";" -f7)" $analyzer4ws_format_date
        responseTimeDate=$_convertedDate

        echo $analyzer4ws_result_count";"$(echo "$line" | cut -d";" -f3,4,5,8)";""$requestTimeDate"";""$responseTimeDate" >> $analyzer4ws_tempfile
    done
}

# print result
function result() {
    if [[ ! analyzer4ws_result_count -eq 0 ]]; then
        if [ "$analyzer4ws_format_table" = "Y" ]; then
            eval "column -t -s ';'" < $analyzer4ws_tempfile
        else
            cat $analyzer4ws_tempfile
        fi

        rm $analyzer4ws_tempfile
    fi
}

check_requirements
load_cfg
analyze
result

# Restore IFS
IFS=$SAVEIFS
exit 0

# groupby and count
# zgrep Response.*.*.*exectime test.sh | cut -d"-" -f3 | sed 's/type=// ; s/sessionId=// ; s/messageId=// ; s/targetService=// ; s/targetOperation=// ; s/requestTime=// ; s/responseTime=// ; s/;exectime=/;/ ; s/-->/;/' | cut -d";" -f4,5 | sort | uniq -c | sort -nr | column -t -s ';'
