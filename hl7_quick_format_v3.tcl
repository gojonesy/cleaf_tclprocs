#########################################################################
# Name:		hl7_quick_format_v3
# Purpose:  To keep specified subfields and repeating
#	  subfields in HL7 messages. This proc eliminates
#     a lot of unnecessary data before being passed to
#	  an XLATE.
#
# UPoC type:	tps
# ARGS: 	tps keyedlist containing the following keys:
#       	MODE    run mode ("start", "run" or "time")
#       	MSGID   message handle
#       	ARGS    user-supplied arguments:
# The argument syntax is as follows:
# SEGNAME = HL7 Segment ID
# FIELD = Field number(s)
# SUBFIELD = Subfield number(s)
# REPSUB = Subfield of repetition to look at for REPCOND
# REPCOND = Repetition value to match on
############################# EXAMPLES ##################################
# This will keep subfield 0 for PID.3 & PID.4
#  ex. {{SEGNAME PID} {FIELD {3 4}} {SUBFIELD 0}}
# This will keep the first 3 subfields for EVN.5
#  ex. {{SEGNAME EVN} {FIELD 5}} {SUBFIELD {0 1 2}}
# This will keep the repetition which matches "Doctor Nbr"
# in PV1.7 & PV1.17
#  ex. {{SEGNAME PV1} {FIELD {7 17}}} {REPSUB 8} {REPCOND {Doctor Nbr}}}
# Please note that each line of arguments needs to be
# enclosed by curly braces. Multiple fields or subfields
# need to be enclosed by curly braces as well.
# {{SEGNAME EVN} {FIELD 5} {SUBFIELD {0 1 2}}}
# {{SEGNAME PID} {FIELD {2 3}} {SUBFIELD 0}}
# {{SEGNAME PID} {FIELD 5} {SUBFIELD {0 1 2}}}
# {{SEGNAME NK1} {FIELD 2} {SUBFIELD {0 1 2}}}
# {{SEGNAME PV1} {FIELD {7 17}} {REPSUB 8} {REPCOND {Doctor Nbr}}}
# {{SEGNAME PV1} {FIELD {7 17}} {SUBFIELD 0}}
# {{SEGNAME PID} {FIELD 11} {REPSUB 6} {REPCOND {home}}}
# {{SEGNAME PID} {FIELD 13} {REPSUB 1} {REPCOND {Home}}}
#########################################################################
# Returns: formatted $mh
#########################################################################
# Written by: Mike Keys
# Date: Aug 21, 2015
# Version: 3.0
#########################################################################

proc hl7_quick_format_v3 { args } {
    keylget args MODE mode      ;# Fetch mode
    set dispList {}             ;# Nothing to return

    switch -exact -- $mode {
        start {
        # Perform special init functions
        # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
			keylget args MSGID mh
			# Now to get the user defined arguments in list format
			set segname {}
			set fields {}
			set subfields {}
			set repsub {}
			set rep_cond {}
			set null {}
			set userargs [lindex [lrange [lindex $args 2] 1 end] 0]
			set rows [llength $userargs]
			set msg [msgget $mh]
			set outbuf {}
			set keep_list ""
			set rep_count 0
			set sub_found ""
			set last_argument 0
			# Now we need to determine our field and sub components
			set field_sep [csubstr $msg 3 1]      ;# HL7 field separator
			set sub_sep [csubstr $msg 4 1]        ;# HL7 subfield separator
			set sub_sub_sep [csubstr $msg 7 1]    ;# HL7 sub-subfield separator
			set rep_sep [csubstr $msg 5 1]        ;# HL7 repetition separator
			set segmentList [split $msg \r]            
			set msgDisp "CONTINUE"
			set loop 0 ;#Set a loop counter so we avoid segment repeats
			foreach segment $segmentList {
				foreach set $userargs {
					set null "N"
					incr loop
					keylget set SEGNAME segname ;#Get segment
					if [cequal [crange $segment 0 2] $segname] {
						keylget set FIELD fields ;#Get field
						keylget set SUBFIELD subfields ;#Get subfields
						keylget set REPSUB rep_sub ;#Get repeating segment subfield index
						keylget set REPCOND rep_cond ;#Get repeating segment condition
						keylget set NULL null ;#Get null field indicator
						if ![cequal $fields ""] {
							set fieldList [split $segment $field_sep]
							foreach field $fields {
								set keep_field [lindex $fieldList $field]
								# This part of the 'if' looks at the rep condition, if present.
								if ![cequal $rep_cond ""] {
									set field_rep [split $keep_field $rep_sep]
									foreach rep $field_rep {
										if ![cequal $rep ""] {
											if [cequal [lindex [split $rep $sub_sep] $rep_sub] $rep_cond] {
												lappend keep_list $rep
											}
										}
									incr rep_count
									#echo $rep_count
									}
								} else {
									# This section deals only with subfields and takes into 
									# consideration subfields that have repetitions left
									# over from a rep_condition argument. 
									set field_rep [split $keep_field $rep_sep]
									#echo $field_rep
									foreach rep $field_rep {
										if ![cequal $rep ""] {
											set num_subs [llength [split $keep_field $sub_sep]]
											set subList [split $keep_field $sub_sep]
											# If null flag is set, then just wipe the field out. 
											# The EXCEPTION to this is fields that have REPEATING segments.
											# In order to wipe out the field, you must pick a repeating segment
											# first, THEN null out the field. 
											# Example: PID.11 (address)
											# {{SEGNAME PID} {FIELD 11} {REPSUB 6} {REPCOND home}}
											# {{SEGNAME PID} {FIELD 11} {NULL Y}}
											if ![cequal $null "Y"] {
												# Loop through each subfield
												for {set i 0} {$i < $num_subs} {incr i 1} {
													#echo "**** STARTING on SEGMENT $segname, FIELD $field, SUBFIELD $i ****"
													# Check to see if subfield contatins data. If it does, then
													# loop through the subfield arguments to see if we need to keep it. 
													# If subfield > num_subs, then this means we want to kill off the data in that field.
													foreach subfield $subfields {
														# Set first argument flag
														if {[cequal $subfield $i] && [expr $i == 0]} {
															set first_argument $subfield
														}
														# Subfield index matches a subfield argument 
														if {[cequal $subfield $i] && [expr $subfield <= $num_subs]} {
															lappend keep_list [lindex $subList $i]
															set sub_found "Y"
															set last_argument $subfield
														} else {
															set last_argument $subfield
														}
														#echo "Subfield argument is: $last_argument"
														#echo "Sub Found flag is:  $sub_found"
														if {[expr $i > $first_argument] && [expr $i < $last_argument] && [cequal $sub_found "N"]} {
															lappend keep_list ""
														}
														#echo "Keep list is now: $keep_list"	
													}
													set sub_found "N"
												}
											} else {
												lappend keep_list ""
											}
										}
									incr rep_count
									#echo $rep_count
									}
								}
								if [expr $rep_count > 1] {
									set new_field [join $keep_list $rep_sep]
									#echo $rep_count
									#echo "the repetition(s) to be retained: $new_field"
									set rep_count 0
								} else {
									#echo $keep_list
									set new_field [join $keep_list $sub_sep]
									#echo "the field(s) to be retained: $new_field"
									set rep_count 0
								}
								catch {set fieldList [lreplace $fieldList $field $field $new_field]}
								set keep_list ""
							}
							
							set segment [join $fieldList $field_sep]
							if [cequal $loop $rows] {
								append outbuf ${segment}\r
								set loop 0
							}
						}
					#OTHER
					} elseif [cequal $loop $rows] {	
						append outbuf ${segment}\r
						set loop 0
					}
					set repsub {}
					set rep_cond {}
				}
			}
			regsub -all {""} $outbuf {} outbuf
			set outbuf [string trimright $outbuf "\r"]
			set outbuf "$outbuf\r"
			msgset $mh $outbuf
			lappend dispList "$msgDisp $mh"
        }
		time {
            # Timer-based processing
        # N.B.: there may or may not be a MSGID key in args
        }
        shutdown {
        # Doing some clean-up work
		}
	}	
    return $dispList
}

