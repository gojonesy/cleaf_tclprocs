######################################################################
# Name:		filter_A04_pyxis
# Purpose:		This kills any A04 messages with Pat Type R or O and not in Table
# Setup		3/07/2005
#		Micro Star, Inc.
#		Brian Wood
#		Integration Analyst
#		bwood@micro-star-inc.com
# Copywrite	Micro Star, Inc.  All rights reserved.
#		www.micro-star-inc.com
# UPoC type:	tps
# Args: 	tps keyedlist containing the following keys:
#       	MODE    run mode ("start", "run" or "time")
#       	MSGID   message handle
#       	ARGS    user-supplied arguments:
#               	<describe user-supplied args here>
#
# Returns: tps disposition list:
#          <describe dispositions used here>
#########################################################################

proc filter_A04_pyxis { args } {
    keylget args MODE mode              	;# Fetch mode

    set dispList {}				;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
	    # N.B.: there may or may not be a MSGID key in args
        }

        run {
	    # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh

		set msg [msgget $mh]
		set splitmsg [split $msg \r]
		set pttypeflag "N"
		set ptlocflag "N"
		set msgstatus "K"

		foreach element $splitmsg {
		   set splitfield [split $element |]
		   set segid [lindex $splitfield 0]
			#find the PV1 segment and set your fields and sub-fields
			if { [cequal $segid PV1]} {
			   # split the fields
			   set pv12 [lindex $splitfield 3]
			   set pv118 [lindex $splitfield 18]

			   # split the sub-fields
			   set pv118sub [split $pv118 ^]
			   set pv12sub [split $pv12 ^]

			   # get the location
			   set location [lindex $pv12sub 0]
			   set pattype [lindex $pv118sub 0]


			    if { [cequal $pattype "SD"] || [cequal $pattype "ER"] || [cequal $pattype "OPB"] || [cequal $pattype "OP"] } {
				set pttypeflag "Y"
            		     } ;#end if

                                   # if pattype = R or O check the table
			    if { [cequal $pattype "RC"] || [cequal $pattype "CL"]} {
				set pttypeflag "C"
            		     } ;#end if

			    if { [cequal $pttypeflag "Y"]} {
			        set msgstatus "C"
			    } else {
			        #Check to see if patient location nurse unit is in emr_pyxis_pt_location.tbl
		 	        set ptlocflag [tbllookup -side input emr_pyxis_pt_location.tbl $location]
                                       #set msgstatus "K"
			        if { [cequal $pttypeflag "C"] && ![cequal $ptlocflag "N"]} {
			            set msgstatus "C"
			        } else {
                                           set msgstatus "K"
			        }

			    }
echo PYXIS pattype $pattype
echo PYXIS location $location
echo PYXIS ptlocflag $ptlocflag
			    if { [cequal $msgstatus "C"] } {
				msgset $mh $msg	
                   			lappend dispList "CONTINUE $mh"
 		                } else {
	              		msgset $mh $msg
	              		lappend dispList "KILL $mh"
	            		}
            		     }
		}		
echo displist $dispList
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
