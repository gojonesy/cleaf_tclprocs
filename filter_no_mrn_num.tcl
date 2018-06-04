######################################################################
# Name:        filter_no_mrn_num
# Purpose:        This kills any message with no MRN number
# Setup        4/13/2005
#        Micro Star, Inc.
#        Jeannette Wistrom
#        Integration Analyst
#        jwisrom@micro-star-inc.com
# Copywrite    Micro Star, Inc.  All rights reserved.
#        www.micro-star-inc.com
# UPoC type:    tps
# Args:     tps keyedlist containing the following keys:
#           MODE    run mode ("start", "run" or "time")
#           MSGID   message handle
#           ARGS    user-supplied arguments:
#                   <describe user-supplied args here>
#
# Returns: tps disposition list:
#          <describe dispositions used here>
#########################################################################

proc filter_no_mrn_num { args } {
    keylget args MODE mode                  ;# Fetch mode

    set dispList {}                ;# Nothing to return

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

            if { [cequal $segid PID]} {
               set mrn [lindex $splitfield 3]

                if { [cequal $mrn ""] } {
echo "No MRN $msg"
                msgset $mh $msg    
                               lappend dispList "KILL $mh"
                         } else {
#echo "MRN found $msg"
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

