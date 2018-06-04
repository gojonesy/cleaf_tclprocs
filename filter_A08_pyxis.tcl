######################################################################
# Name:		filter_A08_pyxis
# Purpose:		This kills any A08 messages Pat Type not I,N,E, or D
#                    or hospital service not = SDOP or not in Table
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

proc filter_A08_pyxis { args } {
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
		set hospserviceflag "N"

		foreach element $splitmsg {
		   set splitfield [split $element |]
		   set segid [lindex $splitfield 0]
			#find the PV1 segment and set your fields and sub-fields
			if { [cequal $segid PV1]} {
			   # split the fields
			   set pv12 [lindex $splitfield 3]
			   set pv118 [lindex $splitfield 18]
			   set pv110 [lindex $splitfield 10]

			   # split the sub-fields
			   set pv118sub [split $pv118 ^]
			   set pv12sub [split $pv12 ^]
			   set pv110sub [split $pv110 ^]

			   # get the patient type, location, and hospital service
			   set location [lindex $pv12sub 0]
			   set pattype [lindex $pv118sub 0]
			   set hospservice [lindex $pv110sub 0]
echo location $location
echo pattype $pattype
echo hospservice $hospservice
                                   # if pattype = I,N,E or D continue message
			    if { [cequal $pattype "IN"] || [cequal $pattype "N"] || [cequal $pattype "ER"]|| [cequal $pattype "D"]} {
				set msgstatus "C"
            		     } ;#end if
#echo msgstatus1 $msgstatus
                                   # if hospital service = SDOP continue message
			    if { [cequal $hospservice "SDO"] } {
				set msgstatus "C"
            		     } ;#end if
#echo msgstatus2 $msgstatus
  
			    #Check to see if patient location nurse unit is in emr_pyxis_pt_location.tbl
		 	    set ptlocflag [tbllookup -side input emr_pyxis_pt_location.tbl $location]

		              #
		              # CMK - Database change to replace flat file table
		              #
		              #set ptlocflag [exec /home/hci/kshlib/database_call.tcl "MMC-SQL-PROD" "CLF_Tables-SQL-PROD" "Notifications" "rick2009" "Location" "loc_code" "$location" "emr_pyxis_pt" "N"]

                                   if { ![cequal $ptlocflag "N"]} {
			            set msgstatus "C"
			    } ;#end if 
#echo msgstatus3 $msgstatus			    
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
