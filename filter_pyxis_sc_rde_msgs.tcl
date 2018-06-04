######################################################################
# Name:		filter_pyxis_sc_rde_msgs
# Purpose:	<description>
# UPoC type:	tps
# Args: 	tps keyedlist containing the following keys:
#       	MODE    run mode ("start", "run" or "time")
#       	MSGID   message handle
#       	ARGS    user-supplied arguments:
#               	<describe user-supplied args here>
#
# Returns: tps disposition list:
#          <describe dispositions used here>
#

proc filter_pyxis_sc_rde_msgs { args } {
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
	  keylget args ARGS uargs

		set msg [msgget $mh]
		set splitmsg [split $msg \r]
		set freqflag T
		
		foreach element $splitmsg {
		   set splitfield [split $element |]
		   set segid [lindex $splitfield 0]

			if { [cequal $segid ORC]} {
			   set ordcntrl [lindex $splitfield 1]
			   if {$ordcntrl == "SC"} {
			      set freqlist [split [lindex $splitfield 7] ^]
			      set freq [lindex $freqlist 1]
			      set freqflag F
			     foreach freq1 $uargs {
			       if { [cequal $freq $freq1] } {
				set freqflag T
				}
			    }
			  }
			}

		}
		if {$freqflag == "T"} {
		    msgset $mh $msg	
                   	    lappend dispList "CONTINUE $mh"

 		} else {
	                msgset $mh $msg
	                lappend dispList "KILL $mh"
echo "Block SC $msg"
	                  }
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
