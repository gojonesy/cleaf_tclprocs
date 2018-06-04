######################################################################
# Name:      tps_replaceField
# Purpose:   Replaces field value with supplied value(s)
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                    List of Segment Name FieldNumber and Value to add
#                    {MSH 8.1 A28} {MSH 9.0 {}} {PID 2.0 12345}
#
# Returns:   tps disposition list:
#            CONTINUE
#
# Notes:     
#
# History:   06/08/2017 Jones Created
#                 
               
proc tps_replaceField { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "tps_replaceField/$HciConnName/$ctx" ;# Use this before every echo/puts,
                                                   ;# it describes where the text came from

    set dispList {}                                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
            
            if { $debug } {
                puts stdout "$module: Starting in debug mode..."
            }
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            
            keylget args MSGID mh
            package require hl7
            set msg [msgget $mh]
            # Process the user args.
            # Formatted thusly - {SEG FIELDNUM VALUE} {SEG FIELDNUM VALUE}
            # Need to add looping to cover fields in repeating fields
            foreach arg $uargs {
                # puts "tps_replaceField - arg: $arg"
                # Replace the given field
                set msg [hl7::replaceField $msg [lindex $arg 0] [lindex $arg 1] [lindex $arg 2]]
            }
            # puts "uargs: $uargs"
            msgset $mh $msg
            lappend dispList "CONTINUE $mh"
        }

        time {
            # Timer-based processing
            # N.B.: there may or may not be a MSGID key in args
            
        }
        
        shutdown {
            # Doing some clean-up work 
            
        }
        
        default {
            error "Unknown mode '$mode' in $module"
        }
    }

    return $dispList
}
