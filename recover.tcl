################################################
# Tcl library of recovery procedures for release 5.6P and above
#	*** This library exists for backward compatibility only ***
#	*** Should be replaced by automatic resend in 5.6P and above ***
#
#	Required procedures:
#	cl_check_ack or similarly configured procedure for Ackowledgements
#		KILLS IB Reply and Clear Await Reply Flag
#		Resends OB msg if needed
#
# Optional procedures - for backward compatibility only 
# (these are no-ops and exist for backward compatibility only)
#	cl_resend_ob_msg   Configure as REPLY GEN 
#	cl_save_ob_msg:    Configure as SEND-OK.   <deprecated>
#	cl_sendOK_save:    Configure as SEND-OK.   <deprecated>
#	cl_kill_ob_save:   Configure as IB REPLY.  <deprecated>
#
#   Use only one of cl_save_ob_msg or cl_sendOK_save.  These procedures
#   do the same thing but were known by different names in some
#   recover_33 packages. 
#
# Optional procedures - for interrogating / handling replies
#	cl_check_ack: Configure as first IB REPLY.  
#		Optional resend based on HL7 acknowledgement
#
#	cl_validate_reply: Example template for reply validation procs.
#		Configure as first IB REPLY.  
#		Optional resend based on acknowledgement
#
######################################################################
# cl_save_ob_msg - In 5.6 Saving is done automatically, 
#		this proc should do nothing
# UPoC type: tps
# Args: tps keyedlist containing:
#       MODE    run mode ("start" or "run")
#       MSGID   message handle
#       ARGS    keyed list of user arguments containing:
#               <describe user supplied args here>
#
# Returns: tps keyed list containing
#       CONTINUE	= all msgs
#
proc cl_save_ob_msg { args } {

    global HciConnName

    set module "$HciConnName/[lindex [info level 1] 0]"

    set dispList {}

    keylget args MODE mode              ;# What mode are we in
    switch -exact -- $mode {
        start {
        }

        run {
            keylget args CONTEXT ctx
            keylget args MSGID mh
            if {$ctx != "send_data_ok"} {
                echo "$module Called with invalid context!"
                echo "$module Should be SEND OK for OB DATA only."
                echo "$module Continuing msg."
            }         
            lappend dispList "CONTINUE $mh"
        }
    }
    return $dispList
}

######################################################################
# cl_sendOK_save - In 5.6 Saving is done automatically, 
#		this proc should do nothing
# UPoC type: tps
# Args: tps keyedlist containing:
#       MODE    run mode ("start" or "run")
#       MSGID   message handle
#       ARGS    keyed list of user arguments containing:
#               <describe user supplied args here>
#
# Returns: tps keyed list containing
#       CONTINUE	= all msgs
#
proc cl_sendOK_save { args } {

    global HciConnName

    set module "$HciConnName/[lindex [info level 1] 0]"

    set dispList {}

    keylget args MODE mode              ;# What mode are we in
    switch -exact -- $mode {
        start {
        }

        run {
            keylget args CONTEXT ctx
            keylget args MSGID mh
            if {$ctx != "send_data_ok"} {
                echo "$module Called with invalid context!"
                echo "$module Should be SEND OK for OB DATA only."
                echo "$module Continuing msg."
            }         
            lappend dispList "CONTINUE $mh"
        }
    }
    return $dispList
}

######################################################################
# cl_resend_ob_msg - If we didn't receive a reply, then resend the msg
#
# UPoC type: tps
#
# Args: tps keyedlist containing:
#       MODE    run mode ("start" or "run")
#       MSGID   message handle
#
# Returns: tps keyed list containing
#       PROTO - Saved message (global)
#       KILL  - Engine message delivered to proc
#
# usage:    'Inbound>Configure...Reply Generation...'
#
proc cl_resend_ob_msg { args } {

    keylget args MODE mode              ;# What mode are we in
    global HciConnName

    set module "$HciConnName/[lindex [info level 1] 0]"
    switch -exact -- $mode {

        start {
      	    return ""
        }

        run {
            keylget args CONTEXT ctx
            keylget args MSGID mh
            keylget args OBMSGID my_mh

      	    # Validate context
            if {![string equal $ctx reply_gen]} {
                echo "\n\n$module Called with invalid context!"
                echo "$module Should be REPLY GENERATION only"
                echo "$module Continuing msg.\n\n"
                return "{CONTINUE $mh}"
            }

            set dispList ""

      	    # If using State 14 recovery (Normal ops)
      	    # Destroy saved msg - resend this one
      	    # Clear the global - resaved after send
      	    set my_mh ""
      	    keylget args OBMSGID my_mh	;# Get handle of outbound message
            if { "$my_mh" != "" } {
            		# Kill saved and resend this one
                lappend dispList "KILL $mh"
                lappend dispList "PROTO $my_mh"

            } else {
		            # Not using state 14 recovery
		            # Simply resend this one
                lappend dispList "PROTO $mh"
            }
            
            # Resend the msg
            echo "$module No response within timeout or state 14 message resent."
            echo "$module Resending msg at [fmtclock [getclock]]"

       	    # Return disposition to engine
            return $dispList
        }
    }
}

######################################################################
# cl_kill_ob_save - in 5.6, OB Saved message is killed automatically 
#		this proc should do nothing
# UPoC type: tps
# Args: tps keyedlist containing:
#       MODE    run mode ("start" or "run")
#       MSGID   message handle
#       ARGS    keyed list of user arguments containing:
#				(nothing)
#
# Returns: tps keyed list containing
#       CONTINUE	= all msgs
#
proc cl_kill_ob_save { args } {

    global HciConnName

    set module "(KILL_OB_SAVE/$HciConnName)"

    set dispList {}

    keylget args MODE mode              ;# What mode are we in
    switch -exact -- $mode {
        start {
        }

        run {
            keylget args MSGID mh
            lappend dispList "KILL $mh"
        }
    }
    return $dispList
}


######################################################################
# Name:	cl_check_ack
# Purpose:	Validate an inbound reply, resend msg if necessary.
# UPoC type:	tps
# Args: 	tps keyedlist containing the following keys:
#       	MODE    run mode ("start" or "run")
#       	MSGID   message handle
#
# Returns: tps disposition list:
#		KILLREPLY = Always kill reply message
#		PROTO	  = reply not OK, count not exceeded, resend 
#		            original message
#		ERROR	  = reply not OK, count is exceeded, send 
#		            original message to Error Database
#
# Notes:
#		Needs the following procs to run correctly:
#			cl_sendOK_save (OB DATA TPS)
#			cl_resend_ob_msg (REPLY GEN TPS)
#
# Check the HL7 acknowledgement received and take action as below:
#
# If AA or CA, Kill saved message and kill reply
#
# If AE or CE, non-recoverable error.  Kill reply and place original
# (saved) message in database (Notify user)
#
# If AR or CR, Possible recoverable error.  Attempt to resend original
# (saved) message up to three times.  If receive more than 3 AR/CR
# replies, treat as AE/CE above.
#
#			
proc cl_check_ack { args } {
    keylget args MODE mode              	;# Fetch mode

    # OBMSGID argument contains handle of outbound message
    # send_cnt is a count of how many resends

    global HciConnName send_cnt

    set module "$HciConnName/[lindex [info level 1] 0]"

    switch -exact -- $mode {

	start {
	    set send_cnt 0	;# Init resend counter

	    return ""
	}

	run {
	    keylget args MSGID mh

	    # Modify to work with CL 5.6
	    set my_mh {}
	    keylget args OBMSGID my_mh	;# Get handle of outbound message

	    # Get a copy of the reply message

	    set msg [msgget $mh]

	    # Split it into HL7 segments and fields
	    # Field separator normally "|"
	    set fldsep [string index $msg 3]

	    # Get segments
	    set segments [split $msg \r]

	    # Get fields from MSA segment
	    set msaflds [split [lindex $segments 1] $fldsep]

	    # Get ACK type from MSA segment and message, if one
	    set acktype [lindex $msaflds 1]
	    set ackmsg [lindex $msaflds 3]

	    if {[lempty $ackmsg]} { set ackmsg "NO MESSAGE" }

	    # Look for all possible hl-7 ack types, 
	    # take appropriate action

	    switch -exact -- $acktype {

		AA - CA {
		    # Good ACK - Clean up
		    set send_cnt 0 		;# Init counter
		    return "{KILLREPLY $mh} {KILL $my_mh}"
		}

		AR - CR {
		    # AR - resend up to 3 times

		    # Have we sent more than 3 times?
		    if {$send_cnt > 3} {

			# Init counter
			set send_cnt 0

			# Tell em bout it and put reason in metadata
			echo "\n$module: Three consecutive AR\
				responses - $ackmsg"
			echo "Message to Error Database"
			echo "Reply is:"
			echo $msg\n\n
			echo "Message is:"
			echo [msgget $my_mh]\n

			# Put reason in metadata and send message to
			# Error database

			msgmetaset $my_mh USERDATA "Exceeded\
			    Application Reject (AR) retrys - $ackmsg"

			return "{KILLREPLY $mh} {ERROR $my_mh}"

		    } else {

			# We haven't resent enough - do it again
			# First, increment counter

			incr send_cnt
			return "{KILLREPLY $mh} {PROTO $my_mh}"
		    }
		}

		AE - CE {
		    # AE in non-recoverable - just send to ERROR database

		    # Init Counter
		    set send_cnt 0

		    # Tell em bout it and put reason in metadata

		    echo "\n$module : Received AE response"
		    echo "Message to Error Database"
		    echo "Reply is:"
		    echo $msg\n\n
		    echo "Message is:"
		    echo [msgget $my_mh]\n

		    # Put message in metadata and message in Error DB

		    msgmetaset $my_mh USERDATA "Application Error\
			    (AE) - $ackmsg"

		    return "{KILLREPLY $mh} {ERROR $my_mh}"
		}

		default {
		    # If we get invalid ACK, trea it as an 
		    # AE - non recoverable

		    # Init Counter
		    set send_cnt 0

		    # Tell em bout it and put reason in metadata

		    echo "\n$module : Received Invalid response"
		    echo "Message to Error Database"
		    echo "Reply is:"
		    echo $msg\n\n
		    echo "Message is:"
		    echo [msgget $my_mh]\n

		    # Put message in metadata and message in Error DB
		    msgmetaset $my_mh USERDATA "Invalid response -\
			    [msgget $mh]"

		    return "{KILLREPLY $mh} {ERROR $my_mh}"
		}
	    }
	}
    }
}


######################################################################
# Name:		cl_validate_reply
# Purpose:	Validate an inbound reply, resend message if necessary.
# UPoC type:	tps
# Args: 	tps keyedlist containing the following keys:
#       	MODE    run mode ("start" or "run")
#       	MSGID   message handle
#       	OBMSGID saved ob message handle
#       	ARGS    user-supplied arguments:
#					(none)
#
# Returns: tps disposition list:
#			CONTINUE	= reply OK, continue it
#			KILLREPLY	= reply not OK, kill it
#			PROTO		= reply not OK, resend original message
#
# Notes:
#	THIS PROCEDURE IS FOR EXAMPLE PURPOSES ONLY.  YOU SHOULD MODIFY
#	THE PROCEDURE TO MATCH THE ACKNOWLEDGEMENT SPECIFICATIONS OF THE
#	REMOTE SYSTEM.
#			
proc cl_validate_reply { args } {

    global HciConnName

    set module "(VALIDATE_REPLY/$HciConnName)"

    set dispList {}

    keylget args MODE mode              	;# Fetch mode
    switch -exact -- $mode {
        start {
            # Perform special init functions
        }

        run {
            keylget args MSGID mh

            set data [msgget $mh]
            if [cequal $data "ACK"] {
                # Reply OK, pass it along
                lappend dispList "CONTINUE $mh"
            } else {
                # OBMSGID is holding message we sent
                keylget args OBMSGID my_mh

                # Kill the reply and resend the original message
                lappend dispList "KILLREPLY $mh"
		            lappend dispList "PROTO $my_mh"
            }
        }
    }
    return $dispList
}

