######################################################################
# Name:      tps_addDRGSegment
# Purpose:   Adds additional DRG segments to message
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                    <describe user-supplied args here>
#
# Returns:   tps disposition list:
#            continue
#
# Notes:     Proc adds a second DRG segment and 2 ZDR segments to messages
#
# History:   09/26/2017 Jones Created
#                 

proc tps_addDRGSegment { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 1  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "tps_addDRGSegment/$HciConnName/$ctx" ;# Use this before every echo/puts,
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
            package require hl7
            keylget args MSGID mh

            if {$debug} { puts "Debug enabled." }
            set msg [msgget $mh]
            
            set drg [hl7::getSegment $msg "DRG"]
            if {$debug} { puts "DRG: $drg" }

            # Insert the segment counter in the DRG segment
            set drg1 [split [join $drg |] |]
            set drg1 [join [linsert $drg1 1 "1"] |]
            if {$debug} { puts "DRG1: $drg1" }
            set drgLen [llength [split $drg1 |]]
            set drg3 [lindex [split $drg1 |] 2]
            set drg13Len [llength [split $drg3 ^]]
            if {$debug} { puts "DRG13 Length: $drg13Len" }
            # Now create the second DRG segment
            set drg2 {}; set drg23 ""
            for {set x 0 } {$x < $drgLen} { incr x} {
                if {$x == 0} { 
                    lappend drg2 "DRG" 
                } elseif {$x == 1 } {
                    lappend drg2 "2"
                } else {
                    lappend drg2 {}
                }
            }
            for {set x 0} {$x < $drg13Len} { incr x } {
                lappend drg23 {}
            }
            set drg23 [join $drg23 ^]
            set drg2 [lreplace $drg2 2 2 $drg23]
            set drg2 [join $drg2 |]

            if {$debug} { puts "new Drg2: $drg2" }
            # Setup the ZDR segments
            set zdr1 [list ZDR "1" {} {} {} {}]
            set zdr2 [list ZDR "2" {} {} {} {}]
            
            # Insert the DRGs backinto the message
            set msgtext [split $msg \r]
            set drgpointer [lsearch $msgtext DRG*]; set msgtext [lreplace $msgtext $drgpointer $drgpointer $drg1]
            set msgtext [linsert $msgtext [expr $drgpointer + 1] $drg2]
            set msgtext [linsert $msgtext [expr $drgpointer + 2] $zdr1]
            set msgtext [linsert $msgtext [expr $drgpointer + 3] $zdr2]
            
            msgset $mh [join $msgtext \r]
            if {$debug} { puts "Msg: [msgget $mh]" }
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
