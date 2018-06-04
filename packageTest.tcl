######################################################################
# Name:      packageTest
# Purpose:   <description>
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                    <describe user-supplied args here>
#
# Returns:   tps disposition list:
#            <describe dispositions used here>
#
# Notes:     <put your notes here>
#
# History:   <date> <name> <comments>
#                 

proc packageTest { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 1  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "packageTest/$HciConnName/$ctx" ;# Use this before every echo/puts,
                                                   ;# it describes where the text came from

    set dispList {}                                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
            
            
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            
            keylget args MSGID mh
            package require hl7
            set msg [msgget $mh]

            puts "Demonstrate getSegment"
            set msh [hl7::getSegment $msg "MSH"]
            puts "MSH: [lindex $msh 0]"
            set obx [hl7::getSegment $msg "OBX"]
            # puts "OBX: $obx"

            puts "Demonstrate getField"
            puts "MSH.9: [hl7::getField [lindex $msh 0] | 8]"
            puts "OBX.3: [hl7::getField $obx | 3]"
            puts "PID.2: [hl7::getField [hl7::getSegment $msg PID] | 2]"
            set pd14 [hl7::getField [hl7::getSegment $msg PD1] | 4]
            puts "pd14: $pd14"

            puts "Demonstrate getSubField"
            puts "getSubField can be done by utilizing the getField proc. "
            puts "MSH.9-1: [hl7::getField [hl7::getField [lindex $msh 0] | 8] ^ 0]"

            puts "Demonstrate countSegments"
            puts "Segment Count [hl7::countSegments $msg]"
            puts "Demonstrate countFields"
            puts "Field Count MSH [hl7::countFields [lindex $msh 0] |]"
            puts "Sub Field count PID.2 [hl7::countFields [hl7::getField [hl7::getSegment $msg PID] | 2] ^]"
            puts "Repeating Field Count PD1.4 [hl7::countFields $pd14 ~]"

            puts "Demonstrate Replacement"
            # set msg [hl7::replaceField $msg MSH 8.1 A28]
            puts "Replacement works, but it will not replace anything but the first iteration in an iterative field."

            puts "Demonstrate Deletion"
            # set msg [hl7::replaceField $msg MSH 9.0 ""]
            

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

