#!/usr/bin/env tcl

######################################################################
# Name        errorDB_alert
# Purpose:    description
# Args:     <site> <recipients> <from>
#           errorDb_alert adt_test jones.justin@mhsil.com interfaceteam@mhsil.com
# Returns:  Sends an email message to the supplied second argument. Defaults to InterfaceTeam@mhsil.com
#           Email is from the 3rd argument and site is used as an Identifier
#           
#           keyedlist containing the following keys:
#           VALUE     The value that is to be used in the COMP operation (required)
#           MESSAGE   The Alert Message, which is accessible in the alert through %A (optional)
#
package require hl7
package require smtp
package require mime

set retval {}
# set args [split $argv]
# puts "args: $argv"; puts "Keys: [keylkeys argv]"
# process args
set from interfaceteam@mhsil.com; set recipients $from
set site "adt_test"; set alertMsg "NONE"
# Changed args to be in a keyed list format - 07/17/2017 - Jones
catch {[keylget argv TO recipients]}; catch {[keylget argv FROM from]}
catch {[keylget argv MSG alertMsg]}; catch {[keylget argv SITE site]}
regsub -all {\{|\}} $alertMsg "" alertMsg
# puts "recipients: $recipients"; puts "from: $from"; puts "alertMsg: $alertMsg"; puts "site: $site"
# if {[lindex $args 1] != "" } { set recipients [lindex $args 1] } 
# if {[lindex $args 2] != "" } { set from [lindex $args 2] } 
# if {[lindex $args 3] != "" } { set alertMsg [lindex $args 3] }

global env
catch { exec $::HciRoot/sbin/hcisetenv -site tcl $site } vars
eval "$vars"
# puts "Alert Message: $alertMsg"
# Get the error db dump
set errorDbDump [split [exec hcidbdump -e -O i] \n]
puts "errorDbDump: $errorDbDump"
# get the last line of the output. This will be the length of the list -2
set lastIndex [expr [llength $errorDbDump] - 3]
# puts "LastIndex: $lastIndex"
# With the last line, we will return the message from the MID on that line:
# puts "[lindex [split [lindex $errorDbDump $lastIndex]] 3]"
# Formatting is different in prod. 
if { [lindex [split [lindex $errorDbDump $lastIndex]] 2] == "" } {
    set mid [string map {\[ "" \] ""} [lindex [split [lindex $errorDbDump $lastIndex]] 2]]
} else {
    set mid [string map {\[ "" \] ""} [lindex [split [lindex $errorDbDump $lastIndex]] 1]]

}

# Get err db output for this message:
set errorDbOutput [split [exec hcidbdump -e -mid $mid -L] \n]
foreach line $errorDbOutput {
    if {$line != ""} {
        puts "[lindex [split $line ":"] 0] - [lindex [split $line ":"] 1] "
        keylset errorKey [string trim [lindex [split $line ":"] 0]] [string trim [lindex [split $line ":"] 1]]
    }
}
set timeStamp [clock format [lindex [split [lindex [split [keylget errorKey msgTimeRecovery] (] 0] "."] 0]]

# Setup the email message:
set msg "<h2>Error Database Message Received in $site</h2>"
append msg "<br><br>" 
append msg "Source Thread: &#9;[keylget errorKey msgSrcThread]<br>"
append msg "Engine ID: &#9;$mid<br>"
append msg "Message Time: &#9;$timeStamp<br>"
append msg "Message State: &#9;<strong>[keylget errorKey msgState]</strong><br>"
append msg "Message ID: [hl7::getField [split [string map {\\x0d \n} [keylget errorKey message]] \n] \"|\" 9]<br>"
append msg "Message Event Type: [hl7::getField [split [string map {\\x0d \n} [keylget errorKey message]] \n] \"|\" 8]<br><br>"
append msg "Message: <br> [string trimleft [string map {\\x0d <br>} [keylget errorKey message]] \"'\"]<br><br>"
append msg "User Data: <br><strong>[keylget errorKey msgUserData]</strong><br><br>"
append msg "<strong>Error Context: <br> "
append msg "<p style=\"color: red;\">"
set lineCount 0
# Need to process multiple lines from the error context to get more detailed information:
foreach line [split [exec hcidbdump -e -mid $mid -c] \n] {
    # Always start at lindex 7 as the 8th line of the readout is where the goods are.
    if {$lineCount >= 7} {
        append msg "$line<br>"
    }
    incr lineCount
}
append msg "</p></strong>"
# append msg "<br><p>Alert Value: $alertMsg</p>"
# append msg "<br><br>$argv"

# Send the email
set token [mime::initialize -canonical text/html -string $msg]
smtp::sendmessage $token -header [list Subject "***PROD*** - A message has entered the error database for $site"] \
                         -header [list To $recipients] \
                         -header [list From $from]

# Clean up the email Handle
mime::finalize $token

# Return a notification that the alert ran to the monitor daemon.
lappend retval "MESSAGE {Tcl alert 'errorDB_alert' has fired.}"
return $retval

