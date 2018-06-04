######################################################################
# Name:		tps_AddUDtoXlateMsg
# Date:		04/12/06
# Author:	Mark McGrath
# Purpose:	Attaches User Data message onto Xlated message to 
#		be interrogated in next Process.
# UPoC type:	sms_ib_data
# Args: 	tps keyedlist containing the following keys:
#       	MODE    run mode ("start", "run" or "time")
#       	MSGID   message handle
#
# Returns: tps CONTINUE modified message
#
# Notes:
#	This is the second part of the from trace file.  This will be used 
#	in the next thread to be set up for Ebcdic conversion and    
#       subsequent trace file creation  Separator - ***XLATED MESSAGE***
# 
###############################################################################

proc tps_AddUDtoXlateMsg { args } {
    keylget args MODE mode              	;# Fetch mode

    #set dispList {}				;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
	    # N.B.: there may or may not be a MSGID key in args
        }

        run {
	    # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            lappend dispList "CONTINUE $mh"
            
            # Get rid of nulls in the message --  this is the xlated message
            set msgtext [msgget $mh]
            
            # Get the userdata - the initial message   from this message
            #  Set the original msg just in case the user data is not set
	    			set origmsg "There is no user data"
	
	    			set userdata [msgmetaget $mh USERDATA]
	    			keylget userdata DATA origmsg
            
            # Now append the Original message and the Xlated message together
            # tied with ***XLATED MESSAGE***
            set bothMessages "$origmsg***XLATED MESSAGE***$msgtext"
            
            # set the msg id to this new combined message format
            msgset $mh $bothMessages
            
            # No modifications just send the unaltered message
            return "{CONTINUE $mh}"
        }
        
        shutdown {
	    # Doing some clean-up work 
	}
    }

    #return $dispList
}
