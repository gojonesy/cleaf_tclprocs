######################################################################
# Name:	filterOnFields
# Author:	10.30.2002 - crboone 
# Purpose:	Filter messages based on HL7 fields/subfields
#	Do NOT use this proc to filter strings (w/spaces). Use
#	'filterOnFieldString' for that purpose. 
#   (*** filterOnFieldString DOES NOT APPEAR TO BE CODED *** 08.27.2008 Brian.Dobbins & Hope.Schnelten
#
# Updates:	2.20.2003 - crboone
#		Added optional MSGTYPE arg (see description below)
#	08.27.2008 - Brian.Dobbins & Hope.Schnelten
#		Add optional TRACEFILE arg 
#			{TRACEFILE <tracefilename>}
#	09.15.2008 - Brian.Dobbins
#		Modified Tracefile location to be e:\TraceFiles\Log
#	05.21.2009 - Brian.Dobbins
#		Modified to add HOSP <hospital> and remove the Tracefile parameter
#
# Caveat:	If you filter on a *repeating* segment, only ONE segment instance has to
#	match the filter criteria. This proc does not allow you to specify a
#	segment instance.
# 
# UPoC type:	tps
# Args:	MSGTYPE - Optional.
#	  - Message Type to filter on.
#	  - Just the Msg Type, or Type & Trig (ie. ORU or ORU^R01)
#	  Allows filtering (KEEP or KILL) only those messages of the specified
#	  msg type while CONTINUE'ing all the others. If no MSGTYPE is specified,
#	  all message types are subject to the filter (ie. if you attempted to keep only
#	  ORU's with OBX 3.1=1234, all ORMs would be killed w/out the MSGTYPE
#	  arg).
#
#	FILTER - Required. HL7 field AND data to filter on.
#	  - Delimiters:	^ delimits between field location and data
#		[SPACE] delimits multiple filters PER field,
#		~ delimits between multiple fields.
#	  - Example:  {FILTER {PV1 18 1^BLANK~OBX 3 1^1234}} {TRACEFILE <tracefilename>}
#	  - Note: To filter on a blank field, use "BLANK" as the FILTER argument
#	  - Caution: If a subfield is not specified, the entire field is assumed!
#
#	MODE - Optional. ANY or ALL; KEEP or KILL.
#	  - Determines if ANY one condition or ALL condition(s) must be met for
#	    multiple filter conditions. ANY is the default if not specified.
#	  - Either KEEP or KILL the message based on the FILTER conditions.
#	    KILL is the default if not specified.
#
#	TRACEFILE - Optional. <tracefilename> 
#	   - Trace file will be located on the E:\TraceFile\Log folder.
#	   - <tracefilename> is the file where the killed messages will be written.
#
#	Examples:
#	{FILTER {MSH 8 1^ORM~PV1 3 1^4NW 2NW}} {MODE {KEEP ALL}} {TRACEFILE <tracefilename>}
#		(Keep only orders from location 4NW & 2NW)
#	{FILTER {MSH 8 1^ORU~MSH 8 2^RO1~OBR 24^LA~OBR 25^P}} {MODE {ALL}} {TRACEFILE <tracefilename>}
#		(Kill Prelim Lab results)
#	{FILTER {MSH 8 1^ORM~PV1 3 1^4NW 2NW}} {MODE {KEEP ALL}} {HOSP <hospital>}
#		(Keep only orders from location 4NW & 2NW)
#	{FILTER {MSH 8 1^ORU~MSH 8 2^RO1~OBR 24^LA~OBR 25^P}} {MODE {ALL}} {HOSP <hospital>}
#		(Kill Prelim Lab results)
######################################################################
proc filterOnFields { args } {

	#****************************************************************
	# THIS LOGIC IS REQUIRED FOR MSG PROCESSING 
	# AND ERROR LOGGING...
	global HciConnName HciSite
	set mode [keylget args MODE]
	set context [keylget args CONTEXT]
	if { ! [info exists HciConnName] } { set HciConnName "UNKNOWN_THREAD" }
	if { ! [info exists HciSite] } { set HciSite "UNKNOWN_SITE" }
	set thread $HciConnName
	set site $HciSite
	set process [file tail [pwd]]
	set dispList {}	;# Nothing to return
	set procname "filterOnFields"	
	set err 0
	#****************************************************************

    switch -exact -- $mode {
    start { # Perform special init functions }
    run {
	# 'run' mode always has a MSGID; fetch and process it
        	keylget args MSGID mh
	set msg [msgget $mh]
	set sfld_sep [crange $msg 4 4]

	set filter ""; set filtermode ""
	set msgtype ""; set typeMatch "N"
	set hosp ""

	keylget args ARGS.MSGTYPE msgtype
	keylget args ARGS.FILTER filter
	keylget args ARGS.MODE filtermode
	keylget args ARGS.HOSP hosp

	# IF MSGTYPE IS UNSPECIFIED, ALL MESSAGE TYPES WILL BE
	# SUBJECT TO THE FILTER.
	if {$msgtype == ""} { 
		set typeMatch "Y"
	} else {
		set msgtypeList [split $msgtype "^" ]
		set msgtypeLength [llength $msgtypeList]
		set msh [getSegment $msg "MSH"]
		set type [getField $msh 8]
		set typeList [split $type $sfld_sep]
		set typeListLength [llength $typeList]

		if {$msgtypeLength >= 2} {
			set msgtype1 [lindex $msgtypeList 0]
			set msgtype2 [lindex $msgtypeList 1]
		} else {	set msgtype1 $msgtype }
		if {$typeListLength >= 2} {
			set type1 [lindex $typeList 0]
			set type2 [lindex $typeList 1]
		} else {	set type1 $type }

		if {$msgtypeLength == 1} { if {$msgtype1 == $type1} { set typeMatch "Y" }
		} else {
			if {$typeListLength == 1} {
				echo "UNABLE TO FILTER MESSAGE BASED ON SPECIFIED MESSAGE TYPE.\nMESSAGE DOES NOT HAVE A TRIGGER.\nMessage will be continued."
				set typeMatch "N"
			} else { if {($msgtype1 == $type1) && ($msgtype2 == $type2)} { set typeMatch "Y" } }
		}
	}

	if {$typeMatch} {

		if {$filtermode == ""} { set modeList ""
		} else { set modeList [split $filtermode] }

		if {([lsearch -exact $modeList "ALL"] < 0)} { set modeList [lappend modeList "ANY"] }
		if {([lsearch -exact $modeList "KEEP"] < 0)} { set modeList [lappend modeList "KILL"] }

		set match "N" ;#Assume msg passes the filter at the beginning...
		set filterList [split $filter ~ ]
		set filterListLength [llength $filterList]
		set filtercnt 1
		set filterSegs ""
		while {$filtercnt <= $filterListLength} {
			set filterIdx [expr $filtercnt-1]
			set currFilter [lindex $filterList $filterIdx]
			set currFilterList [split $currFilter ^ ]
			set currField  [lindex $currFilterList 0]
			set currFieldList [split $currField]
			set seg [lindex $currFieldList 0]
			set field [lindex $currFieldList 1]
			set sfield [lindex $currFieldList 2]
			if {$sfield == ""} { set sfield "none" }

			set filterData [lindex $currFilterList 1]

			# CONVERT ANY SPACES TO AN ENCODING SCHEME TEMPORARILY...
			regsub -all " " $filterData "%sp%" filterData
			set value [list $field $sfield $filterData]
			set value [join $value ^]

			# SET CONDITIONAL TO PREVENT DUPLICATES...
			if {([lsearch -exact $filterSegs $seg] < 0)} {
				set filterSegs [lappend filterSegs $seg]
				keylset kseg $seg $value
			} else {
				keylget kseg $seg existingValue
				set value [lappend existingValue $value]
				keylset kseg $seg $value
			}
			incr filtercnt 1
		}

		set segmentList [split $msg \r]
		set breakfor ""
		foreach segment $segmentList {
			# DETERMINE IF CURRENT SEGMENT IS ONE TO USE FOR FILTERING...
			set seg [crange $segment 0 2]
			if {([lsearch -exact $filterSegs $seg] >= 0)} {

				keylget kseg $seg filters
				set filtersList [split $filters]
				set numFilters [llength $filtersList]
				set ctr 1
				while {$ctr <= $numFilters} {

					set idx [expr $ctr-1]
					set currentFilter [lindex $filtersList $idx]
					set currentFilterList [split $currentFilter ^ ]
					set fld [lindex $currentFilterList 0]
					set sfld [lindex $currentFilterList 1]
					set filterData [lindex $currentFilterList 2]

					# CONVERT ENCODED SPACES BACK TO SPACES...
					regsub -all "%sp%" $filterData " " filterData

					if {$sfld == "none"} { set data [getField $segment $fld]
					} else { set data [getSubfield $segment $fld $sfld $sfld_sep] }

					if {$data == ""} { set data "BLANK"}

					# SPLIT FILTER IN CASE A FILTER LIST WAS PASSED VIA USER ARGS...
					set filterData [split $filterData]
					if {([lsearch -exact $filterData $data] >= 0)} { 
						set match "Y"
						if {([lsearch -exact $modeList "ANY"] >= 0)} { set breakfor "break"; break }
					} else {	
						set match "N"
						if {([lsearch -exact $modeList "ALL"] >= 0)} { set breakfor "break"; break }
					}
					incr ctr 1
				}
			}
			if {$breakfor == "break"} { break }
		}

		if {$match} {
			if {([lsearch -exact $modeList "KEEP"] >= 0)} { lappend dispList "CONTINUE $mh"
			} else { 
	  	    	    set reason "Due to Filter ($filter $filtermode) by filterOnFields."  
echo "kill==> $reason"
			    lappend dispList "KILL $mh" 
			    set Zero [WriteKilledMsgToTracefile $hosp $mh $reason]} 
		} else {
			if {([lsearch -exact $modeList "KEEP"] >= 0)} { 
	  	    	   set reason "Due to Filter ($filter $filtermode) by filterOnFields."  
echo "kill==> $reason"
			   lappend dispList "KILL $mh"
			   set Zero [WriteKilledMsgToTracefile $hosp $mh $reason]
			} else { lappend dispList "CONTINUE $mh" }
		}

	} else { lappend dispList "CONTINUE $mh" }

	return $dispList
    }
    time { # Timer-based processing }
    shutdown { # Doing some clean-up work }
    default { error "Unknown mode '$mode' in $procname" }
    }
}
