#!/usr/bin/env tcl
# Locates all Tables that are not in use and moves them to the backup directory
# 09/15/2017 - Jones - Created
# 02/20/2018 - Jones - Updated to add an email manifest to the script run. 

global HciRoot; set debug 1
set environment [lindex $argv 0]

set scriptName $argv0
set emailTo "InterfaceTeam@mhsil.com"
if {$debug} {set emailTo "jones.justin@mhsil.com" }

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]
# set sites adt_test

if { $debug } { set sitePath /hci/cis6.1/integrator/clvrtest/; set sites /hci/cis6.1/integrator/clvrtest}
set timeNow [clock format [clock scan now] -format {%D %T}]
if { $debug } { puts "$timeNow - Site list: $sites" }

set sitePath "/hci/cis6.1/integrator/*/Xlate/"
set netPath "/hci/cis6.1/integrator/*/"
# Traverse the Tables Directory and search all Xlates for the table.
set tableDir "/hci/cis6.1/integrator/clvrtest/Tables"
catch {exec ls -l /hci/cis6.1/integrator/clvr[string tolower $environment]/Tables | awk {{print $9}} } results options

# Ensure that backup directory exists
catch {eval [exec mkdir /home/hci/backup/Tables]} messages options
if { $debug } { puts "results count: [llength $results]" }
set ctr 0; set resultsList ""

foreach table $results {
    if { $debug } { puts "table: $table" }
    set tableName [lindex [split $table .] 0]
    catch {exec grep -Rilw --include=*.xlt $tableName {*}[glob $sitePath] } xresults xoption
    catch {exec grep -Rilw $table {*}[glob /hci/cis6.1/integrator/*/NetConfig] } nresults noptions
    # Find any that are referenced in a tcl proc
    catch {exec grep -Rilw $table {*}[glob /hci/cis6.1/integrator/*/tclprocs/] } tresults toptions


    # exec grep -Rilw --include=*.xlt prairie_to_emr_trans_codes {*}[glob /hci/cis6.1/integrator/*/Xlate/]
    set status [lindex $xoption 1]
    set nstatus [lindex $noptions 1]
    set tstatus [lindex $toptions 1]

    if { $status && $nstatus && $tstatus } {
        puts "Moving $tableName...."
        lappend resultsList $tableName
        if {!$debug} {eval [exec mv $tableDir/$tableName.tbl /home/hci/backup/Tables/$tableName.tbl]}
        incr ctr
    }


}

puts "Tables moved: $ctr"
puts "resultsList: $resultsList"

# Send out a manifest in an email. This will only generate when ran.
set emailBody "<h2>Results of $scriptName run from $timeNow</h2><br>"
lappend emailBody "<ul>"
foreach result $resultsList {
  lappend emailBody "<li>$result</li>"
}
lappend emailBody "</ul><p>total tables moved: $ctr</p>"

sendMail [join $emailBody \n] "text/html" "Manifest from scriptName script run $timeNow" $emailTo
