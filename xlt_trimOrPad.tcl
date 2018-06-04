######################################################################
# Name:        xlt_trimOrPad
# Purpose:     Based on inVals, trims or pads a supplied field with supplied characters
# UPoC type:   xltp
# Args:        none
# Notes:       All data is presented through special variables.  The initial
#              upvar in this proc provides access to the required variables.
#
#        This proc style only works when called from a code fragment
#        within an XLT.
#
proc xlt_trimOrPad {} {
    upvar xlateId             xlateId             \
        xlateInList         xlateInList         \
        xlateInTypes        xlateInTypes        \
        xlateInVals         xlateInVals         \
        xlateOutList        xlateOutList        \
        xlateOutTypes       xlateOutTypes       \
        xlateOutVals        xlateOutVals        \
        xlateConstType      xlateConstType      \
        xlateConfigFileName xlateConfigFileName 

        # puts "InVals: $xlateInVals"

        # First arg is the value that needs to be manipulated
        # Second, is the action (PAD|TRIM)
        # Third, is the number of spaces to perform the action
        # Fourth, is the character to use for the padding
        # Fifth is to determine where the padding should occur (LEFT|RIGHT)

        set action [lindex $xlateInVals 1]
        set length [lindex $xlateInVals 2]
        # puts "[lindex $xlateInVals 3]"
        # puts "[lindex $xlateInVals 4]"
        set output ""
        if {[lindex $xlateInVals 4] == "LEFT" } { 
            set start 0
            if { $action == "PAD" } {
               for {set i $start} { $i < [expr $length - [string length [lindex $xlateInVals 0]]] } {incr i} {
                    append output [lindex $xlateInVals 3]
               }
               append output [lindex $xlateInVals 0]
            }
            if { $action == "TRIM" } {
                # Remove x characters from start of string.
                set output [string range [lindex $xlateInVals 0] $start [expr $length - 1]]
            }

            # puts "output: $output"
        }
        if {[lindex $xlateInVals 4] == "RIGHT" } { 
            # Adding to the end. We need to add n Chars to the end
            # N Chars - Start
            # For loop - length of output is less than length requested.
            if { $action == "PAD"} {
                set start [string length [lindex $xlateInVals 0]]
                for {set i $start} {$i < $length } {incr i} {
                    append output [lindex $xlateInVals 3]
                }
            }
            if { $action == "TRIM" } {
                set start [expr [string length [lindex $xlateInVals 0]] - $length]
                # Remove x characters from start of string.
                set output [string range [lindex $xlateInVals 0] $start [expr $start + [expr $length - 1]]]
            }
            # puts "output: $output"
            
            
        } 
        set xlateOutVals $output
}
