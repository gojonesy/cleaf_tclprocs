#!/usr/bin/tclsh
# Created by Jones - 05/11/2017
# Package for routine HL7 message parsing and processing.
package require Tcl 8.3;                # tcl minimum version

namespace eval ::hl7 {
	variable version 1.0
	
    namespace export getSegment getField countSegments countFields parseMsg getFieldDescriptions getDelims replaceField
}

# Gets a segment and returns it as a list (in case of multiple segments)
proc ::hl7::getSegment { msg segment } {
	set segList [split $msg \r]
	set returnSegs ""
	foreach seg $segList {
		if {[lindex [split $seg "|"] 0] == $segment} {
			lappend returnSegs $seg
		}
		
	}
	
	return $returnSegs
}
# Gets a field and returns it as a string
# Can be used on subfields and repeating fields, as well.
# Str is a string with the text that needs parsed, Delimiter is what to split on and num is the lindex of the field desired
proc ::hl7::getField { str delimiter num } {
	set retVal [lindex [split $str $delimiter] $num];
	
	return $retVal
}

# Replaces a field in the message with the supplied value. 
# Can be used on subfields and repeating fields, as well.
# Expects a full message and will return a full, HL7 formatted message
proc ::hl7::replaceField { msg seg field replaceVal } {
	set retVal ""
	# The message should be passed in as a list..
	if {[llength $msg] > 1} {
		# puts "Message is not a list. Split it."
		set msg [split $msg \r]
	}
	
	# Find the supplied field
	set segmentNum [lsearch -all -glob $msg $seg|*]
	set segment [lindex $msg $segmentNum]
	set fieldNum [lindex [split $field .] 0]; set subField [lindex [split $field .] 1]
	# puts "FieldNum: $fieldNum"; puts "Subfield: $subField"
	set fieldVal [lindex [split [lindex [split $segment "|"] $fieldNum] "^"] $subField]
	# puts "fieldVal: $fieldVal"
	
	#Rebuild the entire field
	set fieldList [lindex [split $segment "|"] $fieldNum]
	# puts "fieldList: $fieldList"
	set fieldList [join [lreplace [split $fieldList "^"] $subField $subField $replaceVal] "^"]
	# Replace the field
	set segment [lreplace [split $segment "|"] $fieldNum $fieldNum $fieldList]
	# puts "segment: $segment"
	
	# Put the message back together
	set msg [lreplace $msg $segmentNum $segmentNum [join $segment "|"]]
	set msg [join $msg \r]
	
	return $msg
}
# Counts the segments in a supplied message. Uses the \r character for counts.
proc ::hl7::countSegments { msg } {
	# upvar segDelimiter segDelimiter
	set segList [split $msg \r]
	# remove any empty list items
	for { set i 0 } { $i < [llength $segList] } { incr i } {
		if { [lindex $segList $i] == {} } { 
			# Remove the empty segments
			lvarpop segList $i
		}	
	}
	# puts "segList: $segList"
	return [llength $segList]
}
# Counts the fields in a supplied segment.
proc ::hl7::countFields { segment delimiter } {
	set fieldList [split $segment $delimiter]

	return [llength $fieldList]
}


# Parses an HL7 passed in HL7 Message
# Returns the parsed message
proc ::hl7::getDelims { msg } {
    set delims "\r"
    append delims [string index $msg 3]
    append delims [string index $msg 5]
    append delims [string index $msg 4]
    append delims [string index $msg 7]
    # puts "delims = $delims"
    return [list 0 $msg $delims]
}

# Traverses the hl7 formats directory and returns the field descriptions
proc ::hl7::getFieldDescriptions { hl7Version } {
	set formatsDir "$::HciRoot/formats/hl7/"
	# set hl7Version "2.3"
	set formatsDir $formatsDir$hl7Version

	set fields [read_file "$formatsDir/fields"]
	regsub {^.*end_prologue\n} $fields "" fields
	set allFields ""
	# puts "formatsDir - $formatsDir"
	foreach line [split $fields \n] {
		if {$line != "" } {
			lappend allFields [list [keylget line ITEM] [keylget line NAME]]
			# set allFields([keylget line ITEM]) [keylget line NAME]
		}
	}
	# puts "allfields: $allFields"
	set allSegs ""
	foreach file [glob "$formatsDir/segments/*"] {
		set fields [read_file $file]
		regsub {^.*end_prologue\n} $fields "" fields
		set seg [file tail $file]
		set lines [split $fields \n]
		# puts "seg: $seg"
		foreach line $lines {
			if {$line != ""} {
				lappend allSegs [list $seg [keylget line ITEM]]
			}
			
		}
		
	}
	
	return [list $allFields $allSegs]
}

package provide hl7 $::hl7::version

namespace import ::hl7::*
