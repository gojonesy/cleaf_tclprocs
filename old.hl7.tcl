#!/usr/bin/tclsh

# $Id$
package require Tcl 8.2

namespace eval ::hl7 {
    namespace export get_field set_field join_msg parse_msg delete_seg append_seg trim_seg count
}

# Prepares a message to be processed by the get_field and set_field procs.
#
# @param  msg the HL7 message to be parsed
# @return the parsed message
proc ::hl7::parse_msg { msg } {
    set delims "\r"
    append delims [string index $msg 3]
    append delims [string index $msg 5]
    append delims [string index $msg 4]
    append delims [string index $msg 7]
    #puts "delims = $delims"
    return [list 0 $msg $delims]
}

proc ::hl7::join_2 { fieldparts level } {
    #puts "debug ::hl7::join $fieldparts $level"
    upvar delims delims
    set issplit [lindex $fieldparts 0]
    if { !$issplit } {
	#    puts "return [lindex $fieldparts 1]"
	return [lindex $fieldparts 1]
    }
    set delim [string index $delims $level]
    set parts [lindex $fieldparts 1]
    set retval ""
    for { set i 0 } { $i < [llength $parts] } { incr i } {
	if { $level == 1 && $i == 1 && [::hl7::join_2 [lindex $parts 0] [expr $level+1]] eq "MSH" } {
	    # strip out the first field (field sep) from MSH
	    continue
	}
	if { $i > 0 } {
	    append retval $delim
	}
	append retval [::hl7::join_2 [lindex $parts $i] [expr $level+1]]
	#echo $level adding [lindex $parts $i]
    }
    if { $delim eq "\r" } {
	# segment terminator also appears after last seg
	append retval "\r"
    }
    #  puts "join returning $retval"
    return "$retval"
}

# Joins the parts of a parsed message back into HL7 format.
#
# @param hl7var A list of message parts to be joined back together.
# @return The message in HL7 format.
proc ::hl7::join_msg { hl7var } {
    upvar $hl7var hl7
    set delims [lindex $hl7 2]
    return [::hl7::join_2 $hl7 0]
}

proc ::hl7::split_part { hl7var level } {
    upvar $hl7var hl7
    upvar delims delims

    #echo split_part $hl7var ([set $hl7var]) $level

    set delim [string index $delims $level]

    # if this node hasn't been split, split this node
    set newparts {}
    set parts [lindex $hl7 1]
    set parts_list [split $parts $delim]
    for { set i 0 } { $i < [llength $parts_list] } { incr i } {
	set part [lindex $parts_list $i]
	if { $level || $part ne "" } {
	    lappend newparts [list 0 $part]
	}
	if { $level == 1 && $i == 0 && [lindex $parts_list 0] eq "MSH" } {
	    # add extra field for MSH
	    lappend newparts [list 0 {|}]
	}
    }
    set parts $newparts
    # set this node as a "parent" node
    set hl7 [list 1 $parts]
    if { !$level } {
	lappend hl7 $delims
    }
}

proc ::hl7::getset { mode hl7var fieldparts changedvar level newval } {
    upvar $hl7var hl7 ;# the (perhaps partially split) message
    upvar $changedvar changed ;# whether or not we changed the message (by splitting or setting it)
    # puts "debug ::hl7::getset $mode $hl7var $fieldparts"
    # puts "  $hl7var = $hl7"

    if { ! $level } {
	set delims [lindex $hl7 2]
    } else {
	upvar delims delims
    }
    set delim [string index $delims $level]

    set issplit [lindex $hl7 0]

    #set fieldparts [split $field .]
    if {![llength $fieldparts]} {
	# no more field specifiers; we found the field
	if { $mode eq "GET" } {
	    # return the value of the current field
	    return [::hl7::join_2 $hl7 $level]
	} elseif { $mode eq "INDEX" } {
	    return {}
	} elseif { $mode eq "COUNT" } {
	    #puts "parts is $parts"
	    #puts "count is [llength $parts]"
	    if { !$issplit } {
		::hl7::split_part hl7 $level
		set changed 1
	    }
	    set parts [lindex $hl7 1]
	    return [llength $parts]
	} elseif { $mode eq "SET" } {
	    # set the value of the current field
	    set hl7 [list 0 $newval]
	    set changed 1
	    return 1
	} else {
	    error "unknown mode $mode"
	}
    }

    if { !$issplit } {
	::hl7::split_part hl7 $level
	set changed 1
    }
    set parts [lindex $hl7 1]

    if { !$level } {
	# if this is at the segment level, find the matching segment
	set count 0
	
	for { set i 0 } { $i < [llength $parts] } { incr i } {
	    set segdata [lindex $parts $i]
	    set newchanged 0

	    # try to avoid splitting a segment just to get the name
	    set issplit2 [lindex $segdata 0]
	    if { !$issplit2 } {
		set segname [string range [lindex $segdata 1] 0 2]
	    } else {
		set segname [::hl7::getset GET segdata 0 newchanged 1 ""]
	    }
	    # puts "segname = $segname"

	    if { $segname eq [lindex $fieldparts 0] ||
		 [lindex $fieldparts 0] eq $i+1 } {
		# puts "found our segment"
		if { [llength $fieldparts] > 1 || $mode ne "COUNT" } {
		    if { $count == [lindex $fieldparts 1] } {
			set retval [::hl7::getset $mode segdata \
					[lrange $fieldparts 2 end] \
					newchanged 1 $newval]
		    }
		}
		incr count
	    }
	    # update any expanded segs in message
	    if { $newchanged } {
		set parts [lreplace $parts $i $i $segdata]
		set hl7 [list 1 $parts $delims]
		set changed 1
	    }
	    if { [info exists retval] } {
		if { $mode eq "INDEX" } {
		    set retval [linsert $retval 0 [expr $i+1]]
		}
		return $retval
	    }
	}
	# segment not found
	if { $mode eq "COUNT" } {
	    return $count
	} elseif { $mode eq "GET" } {
	    return ""
	} elseif { $mode eq "INDEX" } {
	    return 0
	} elseif { $mode eq "SET" } {
	    error "segment not found, hl7 = $hl7"
	} else {
	    error "unknown mode"
	}
    } else {
	#puts "subfield stuff here"
	set newchanged 0
	set fieldnum [lindex $fieldparts 0]
	while { [llength $parts] < $fieldnum + 1 } {
	    if { $mode eq "GET" } {
		# we asked for a field number greater than the number of fields.
		# if we are in GET mode, return null.
		return ""
	    } elseif { $mode eq "COUNT" } {
		return 0
	    } elseif { $mode eq "INDEX" } {
		return 0
	    } elseif { $mode eq "SET" } {
		# if we are in set mode, append empty fields.
		lappend parts { 0 {} }
		set newchanged 1
	    }
	}
	set subfield [lindex $parts $fieldnum]
	set retval [::hl7::getset $mode subfield [lrange $fieldparts 1 end] \
			newchanged [expr $level+1] $newval]
	if { $newchanged } {
	    set parts [lreplace $parts [lindex $fieldparts 0] \
			   [lindex $fieldparts 0] $subfield]
	    set hl7 [list 1 $parts]
	    set changed 1
	}

	if { $mode eq "INDEX" } {
	    if { $level == 1 } {
		set offset 0
	    } else {
		set offset 1
	    }
	    set retval [linsert $retval 0 [expr $fieldnum+$offset]]
	}
	
	#    puts "hl7 = $hl7"
	#    puts "level $level result $retval"
	return $retval
    }
}

proc ::hl7::field_parse { hl7var mode infield } {
    upvar $hl7var hl7
#    puts "debug ::hl7::field_parse $mode $infield"
    set ismsh 0

    #set inparts [split $infield .]
    set inpart ""
    set parens 0
    set inparts {}
    #echo infield = $infield
    set strlen [string length $infield]
    if { $strlen } {
	for { set i 0 } { $i < $strlen } { incr i } {
	    set ch [string index $infield $i]
	    if { $ch eq "." && !$parens } {
		lappend inparts $inpart
		set inpart ""
	    } else {
		if { $ch eq "(" } {
		    incr parens
		} elseif { $ch eq ")" } {
		    incr parens -1
		}
		append inpart $ch
	    }
	}
	lappend inparts $inpart
    }

    set outparts {}
    for { set i 0 } { $i < [llength $inparts] } { incr i } {
	set inpart [lindex $inparts $i]
	#    puts "inpart = $inpart"
	if { $i < 2 } {
	    # see if repetition number was specified
	    if { [regexp {^(\w+)\((.+)\)$} $inpart -> fieldnum query] } {
		set is_query 0
		foreach query_type { = ~ } {
		    set query_parts [split $query $query_type]
		    if { [llength $query_parts] != 2 } {
			continue
		    }
		    set is_query 1
		    set search_base [lrange $inparts 0 [expr $i-1]]
		    lassign $query_parts query_loc query_val
		    lappend search_base $fieldnum
		    set search_base [join $search_base .]
		    set count [::hl7::count hl7 $search_base]
		    for { set repnum 1 } { $repnum <= $count } {
			incr repnum } {
			set result [::hl7::get_field hl7 \
					${search_base}($repnum).$query_loc]
			if { ($query_type eq "=" &&
			      $result eq $query_val) ||
			     ($query_type eq "~" &&
			      [regexp -- $query_val $result]) } {
			    # match was found so exit the loop and leave
			    # repnum with the correct value
			    break
			}
		    }
		}
		if { !$is_query } {
		    set repnum $query
		}
	    } else {
		# if not, default repetition number to 1
		set fieldnum $inpart
		#if { $mode eq "COUNT" && $i+1 == [llength $inparts] } {}
		if { $i+1 == [llength $inparts] } {
		    # unless we're trying to count
		    set repnum ""
		} else {
		    set repnum 1
		}
	    }
	    if { $i == 0 } {
		if { [string is integer $fieldnum] } {
		    if { $repnum ne "" && $repnum ne "1" } {
			error "repetition number specified for numbered segment"
		    }
		    set repnum 1
		}
	    }
	    lappend outparts $fieldnum
	    if { $repnum ne "" } {
		if { $repnum < 1 } {
		    error "repetition number less than 1"
		}
		lappend outparts [expr $repnum-1]
	    }
	} else {
	    if { $inpart < 1 } {
		error "[lindex { segment segrep field fieldrep component subcomponent } $level] number less than 1"
	    }
	    lappend outparts [expr $inpart-1]
	}
    }
    
    # this allows you to use "get_field $segname" to get the entire segment
    if { [llength $outparts] == 1 && $mode ne "COUNT" } {
	lappend outparts 0
    }
#    puts "result = $outparts"
    return $outparts
}

proc ::hl7::getset_2 { mode hl7var field value } {
    # puts "debug ::hl7::getset_2 $mode $hl7var $field $value"
    upvar $hl7var hl7
    # puts "hl7 = <$hl7>"
    set dummy 0
    return [::hl7::getset $mode hl7 [::hl7::field_parse hl7 $mode $field] \
		dummy 0 $value]
}

# Retrieves the value for a specified field from a parsed message.
#
# @param hl7var The variable containing the parsed message.
# @param field Which field to get from the message
# @return The value of the specified field or an empty string if the field is blank or not present.
proc ::hl7::get_field { hl7var field } {
    upvar $hl7var hl7
    return [::hl7::getset_2 GET hl7 $field ""]
}

proc ::hl7::get_index { hl7var field } {
    upvar $hl7var hl7
    return [::hl7::getset_2 INDEX hl7 $field ""]
}

# Sets the value for a specified field in a parsed message.
#
# @param hl7var The variable containing the parsed message.
# @param field Which field to get from the message
# @param value The value to put in the field.
# @return 1 on success. Throws error for most failures.
proc ::hl7::set_field { hl7var field value } {
    upvar $hl7var hl7
    return [::hl7::getset_2 SET hl7 $field $value]
}

# Counts the segments, fields or subfields in a message.
#
# @param hl7var The parsed HL7 message.
# @param field The item that should be counted
# @return The count of the specified field in this message.
proc ::hl7::count { hl7var field } {
    upvar $hl7var hl7
    return [::hl7::getset_2 COUNT hl7 $field ""]
}

# Removes empty values from the end of a segment or field
#
# @param hl7var The parsed HL7 message.
# @param field The item that should be trimmed
proc ::hl7::trim_seg { hl7var field } {
    upvar $hl7var hl7
    set num [expr [::hl7::get_index hl7 $field] - 1] ;# get the segment number
    ::hl7::getset_2 COUNT hl7 $field "" ;# force the segment to be split
    set msg [lindex $hl7 1]
    set seg [lindex [lindex $msg $num] 1] ;# grab the split segment out of the list
    while { [llength $seg] } {
	set last_field [lindex $seg end]
	if { [lindex $last_field 0] == 0 &&
	     [lindex $last_field 1] eq "" } {
	    set seg [lrange $seg 0 end-1] ;# remove the last field if it is blank
	} else {
	    break
	}
    }
    set seg [list 1 $seg] ;# put the field list back in the segment
    set msg [lreplace $msg $num $num $seg] ;# put the segment back in the segment list
    set hl7 [lreplace $hl7 1 1 $msg] ;# put the segment list in the message
}
    
# Removes a segment from the message.
#
# @param hl7var The parsed HL7 message.
# @param field The name of the segment to remove with optional field specifiers.
proc ::hl7::delete_seg { hl7var field } {
    upvar $hl7var hl7
    set num [expr [::hl7::get_index hl7 $field]-1]
    set segs [lreplace [lindex $hl7 1] $num $num]
    set hl7 [lreplace $hl7 1 1 $segs]
}

# Appends a segment to the message.
#
# @param hl7var The parsed HL7 message.
# @param after The segment after which to append the new segment.
proc ::hl7::append_seg { hl7var seg args } {
    upvar $hl7var hl7

    if { [llength $args] } {
	set after [lindex $args 0]
	set where [lindex [::hl7::get_index hl7 $after]]
	set segs [lindex $hl7 1]
	set segs [linsert $segs $where [list 0 $seg]]
	set hl7 [lreplace $hl7 1 1 $segs]
    } else {
	set issplit [lindex $hl7 0]
	if { $issplit } {
	    set segs [lindex $hl7 1]
	    set hl7 [lreplace $hl7 1 1 [lappend segs [list 0 $seg]]]
	} else {
	    set msg [lindex $hl7 1]
	    set hl7 [lreplace $hl7 1 1 [append msg "$seg\r"]]
	}
    }
}

package provide hl7 1.2
