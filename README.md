# analyzer.sh v0.2.0

```
Analyzer for web services based on axis1
Copyright (c) Marco Lovazzano
Licensed under the GNU General Public License v3.0
http://github.com/martcus

Usage: analyzer.sh [OPTIONS]
      --help                     : Print this help
      --version                  : Print version
 -f , --file [FILENAME]          : Set the filename to scan.
 -l , --lines [FILENAME]         : Set the number of max lines to retrieve.
 -d , --dateformat [DATE FORMAT] : Set the date format for requesttime and responsetime. Refer to date command (man date).
                                 : Default value is: +%H:%M:%S
 -s , --service [SERVICE]        : Set the filter by <targetService>
 -o , --operation [OPERATION]    : Set the filter by <targetOperation>
 -t , --table                    : Diplay the output as a table
      --orderby [FIELD}          : Specifies the field for which sorting is performed.
                                   The options are: requesttime, responsetime, exectime.
                                   Default value: exectime.

Exit status:
 0  if OK,
 1  if some problems (e.g., cannot access subdirectory).
```
Example:
```
./analyzer.sh -f ws.log -l 20 -t --order exectime
```
