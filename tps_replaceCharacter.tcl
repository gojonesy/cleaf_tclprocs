######################################################################
# Name:      tps_replaceCharacter
# Purpose:   Removes supplied character from entire message or from
#            supplied segment or field
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                    <describe user-supplied args here>
#
# Returns:   tps disposition list:
#            CONTINUE
#
# Notes:     
#
# History:   06/08/2017 Jones Created
#                 

proc tps_replaceCharacter { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "tps_replaceCharacter/$HciConnName/$ctx" ;# Use this before every echo/puts,
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
            
            keylget args MSGID mh; set segment ""; 
            catch {keylget uargs SEGMENT segment}; 
            keylget uargs CHAR char; keylget uargs REPCHAR replaceChar
            set msg [msgget $mh]
            if {$segment != "" } {
                # Remove just the character from ONLY the specified segment.
                foreach seg [split $msg \r] {
                    puts "seg: $seg"
                    if {[lindex [split $seg "|"] 0] == $segment} {
                        set seg [regsub -all $char $seg $replaceChar]
                        puts "seg: $seg"
                    }
                    lappend newMsg $seg
                }
                # puts "newMsg: $newMsg"
                set newMsg [join $newMsg \r]
            } else {
                # Remove the character from the whole message.
                set newMsg [regsub -all $char $msg $replaceChar]
            }
            
            msgset $mh $newMsg
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
