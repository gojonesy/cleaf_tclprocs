#!/usr/bin/env tcl

# Example 01: msgParser file.hl7
# Example 02: msgParser *.hl7
# Example 03: msgParser file.dat *.hl7
# Example 04: msgParser *
# Example 05: msgParser -seg *
# Example 06: msgExtract | msgParser -seg (Convert a smat file to a nl file and pipe the result)
# Note: The output of this script is designed to work well with grep/egrep and other unix/linux commands

# Decide to print HL7 segments or HL7 fields
if {[lindex $argv 0] == "-seg"} {
    set segFlag "1"
    set pattern [lsort [lrange $argv 1 end]]
} else {
    set segFlag "0"
    set pattern [lsort $argv]
}

# Parse the message into segments or fields
proc parse {type} {
    global seg segFlag msg i

    if {$msg == ""} {return ""}
    incr i
    catch {puts "\nMessage: [format "%02s" $i] ($type)\n"}

    foreach seg [split $msg \r] {
        if {$seg == ""} {continue}
        if {$segFlag == "1"} {catch {puts $seg}; continue}

        set fldDel [string range $seg 3 3]
        set subDel [string range $seg 4 4]
        set segName [string range $seg 0 2]
        set seg [string range $seg 4 end]
        set j 0; if {$segName == "MSH"} {set j 1}

        if {$segName == "MSH"} {catch {puts "MSH.01: $fldDel"}}

        foreach fld [split $seg $fldDel] {
            set j [expr $j + 1]
            if {$fld != ""} {
                catch {puts "$segName.[format "%02s" $j]: $fld"}
            } else {
                continue
            }
        }
    }
}

set i 0

# Process file given as arguments to the script (ex. msgParser *.hl7 *.dat)
foreach file $pattern {
    set i 0
    set f [open $file r]; fconfigure $f -translation binary; set messages [read $f]; close $f
    if {$messages == ""} {continue}
    if {![regexp {MSH} $messages]} {continue}
    foreach msg [split $messages \n] {parse $file}
}

# Process messages piped from stdin (ex. msgExtract smat.msg | msgParser -seg)
fconfigure stdin -translation binary
if {!$i} {while {[gets stdin msg] >= 0} {parse "stdin"}}