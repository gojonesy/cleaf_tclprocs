######################################################################
# Name:		IV_Cont_Anti_filter
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

proc IV_Cont_Anti_filter { args } {
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
		
		foreach element $splitmsg {
		   set splitfield [split $element |]
		   set segid [lindex $splitfield 0]

			if { [cequal $segid RXO]} {
			   set rxfield [lindex $splitfield 1]
echo "Inside first IF $rxfield"
			   set splitsubfield [split $rxfield ^]
			   set rxsubfield [lindex $splitsubfield 0]
echo "SubField EQUALS $rxsubfield"  
			    if { [cequal $rxsubfield "RXCUST"] } {

echo "Ignored $rxsubfield"

				msgset $mh $msg	
                   			lappend dispList "KILL $mh"
 		                } else {
	              		msgset $mh $msg
	              		lappend dispList "CONTINUE $mh"
	            		}
            		     }
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
