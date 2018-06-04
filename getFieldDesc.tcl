######################################################################
# Name:      getFieldDesc
# Purpose:   Given a message, will return as HTML formatted Table or Text all of the messages
#            fields along with their Cloverleaf defined descriptions
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                    SEGMENTS <Optional, Default ALL, ` delimited>
#                    OUTPUT <TEXT|HTML>, Defaults to Text
#                    EMAIL <Comma delimited list of email addresses to send the output to>
#                    VERSION <HL7 Version to get Field Descriptions from, Default 2.3>
#
# Returns:   tps disposition list:
#            CONTINUE
#
# Notes:     
#
# History:   06/01/2017 Jones Created
#                 

proc getFieldDesc { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "getFieldDesc/$HciConnName/$ctx" ;# Use this before every echo/puts,
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
            # Requires the hl7 package.
            package require hl7

            set msg [msgget $mh]
            set version 2.3
            catch {keylget uargs VERSION version}
            set allFields [lindex [hl7::getFieldDescriptions $version] 0]
            # Turn allFields into a keyed list...
            foreach field $allFields {
                keylset keyFields [lindex $field 0] [lindex $field 1]
            }
           
            set allSegs [lindex [hl7::getFieldDescriptions 2.3] 1]
            #Get all of the MSH values:
            set mshVals [lsearch -all -inline -glob $allSegs "MSH*"]
            set msh10 [hl7::getField [lindex [hl7::getSegment $msg MSH] 0] | 9]
            # Get the args that tell us which segments to breakdown and how to output.
            set segments ""; set output ""; set emailTo ""
            catch {keylget uargs SEGMENTS segments}; catch {keylget uargs OUTPUT output}
            catch {keylget uargs EMAIL emailTo}

            # Start to build output
            set formatStr {%25s%25s%25s}
            if { [string toupper $output] == "HTML" } {
                # Output as HTML table.
                lappend outList "<html><head></head>\n"
                lappend outList "<body><h1>Field Descriptions</h1><br>\n"
                lappend outList "<h3>Showing $segments from message [hl7::getField [lindex [hl7::getSegment $msg MSH] 0] | 9]</h3><br>\n"
                lappend outList "<table border=1>\n"
                lappend outList "<tr><th>Field</th><th>Descriptor</th><th>Value</th></tr>"
            } else {
                # Output is a simple text formatted table.
                lappend outList "#####\tField Descriptions\t#####"
                lappend outList "#####\tShowing $segments from message [hl7::getField [lindex [hl7::getSegment $msg MSH] 0] | 9]\t#####"
                lappend outList "[format $formatStr \"Field\" \"Value\" \"Descriptor\"]"
                lappend outList "[format $formatStr \"------\" \"------\" \"------\"]"
            }

            # puts "outList: $outList"
            if {[llength $segments] >= 1} { 
                # We only need the descriptions for the supplied segments
                set segments [split $segments "`"]; puts "Segments: $segments"
                foreach seg $segments {
                    set segVals [lsearch -all -inline -glob $allSegs "[string toupper $seg]*"]
                    # Handle repeating segments
                    set segCount 0
                    foreach s [hl7::getSegment $msg $seg] {
                        set fieldCounter 1; set countMod 0; 
                        # MSH requires math on the field counter...
                        if {$seg == "MSH"} { set countMod 1 }
                        # Get all of the field Descriptions for this segment and build output
                        foreach val $segVals {
                            if {[string toupper $output] == "HTML"} {
                                lappend outList "<tr><td>$seg.$fieldCounter</td>"
                                lappend outList "<td>[keylget keyFields [lindex [split $val] 1]]</td>"
                                lappend outList "<td>[hl7::getField [lindex [hl7::getSegment $msg $seg] $segCount] | [expr $fieldCounter - $countMod]]</td></tr>"
                            } else {
                                # lappend outList "#####\t$seg.$fieldCounter\t[hl7::getField [lindex [hl7::getSegment $msg $seg] $segCount] | [expr $fieldCounter - $countMod]]\t[keylget keyFields [lindex [split $val] 1]]\t#####"
                                lappend outList "[format $formatStr $seg.$fieldCounter [hl7::getField [lindex [hl7::getSegment $msg $seg] $segCount] | [expr $fieldCounter - $countMod]] [keylget keyFields [lindex [split $val] 1]]]"
                            }
                            incr fieldCounter; incr mshCounter;
                        }
                        incr segCount
                    }

                }
            }

            # Finish off formatting
            if {[string toupper $output] == "HTML"} {
                lappend outList "</table>\n</body>\n</html>"
            }
            set msg [join $outList \n]
            # Boom. 
            msgset $mh "$msg"
            # Should we email it?
            if {$emailTo != ""} {
                # Ensure that the addresses are valid.
                foreach to [split $emailTo ","] {
                    # Check format of address
                    if {[regexp {(^[A-Za-z0-9._-]+@[[A-Za-z0-9.-]+$)} $to]} {
                        sendMail [msgget $mh] "text/html" "$segments for $msh10" $to
                    }
                }
                
            }
            
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
proc sendMail { body content_type subject to } {
    package require mime
    package require smtp

    # create an image and text
    set textT [mime::initialize -canonical $content_type -string $body]
    #     set psT [mime::initialize -canonical \
    #                  "text/plain; name=\"report.txt\"" -string $psmsg]

    # create a multipart containing both, and a timestamp
    set multiT [mime::initialize -canonical multipart/mixed \
                    -parts [list $textT]]

    smtp::sendmessage $multiT \
    -header [list To $to] \
    -header [list Subject $subject] \
    -servers { localhost } \
    -header [list From "InterfaceTeam@mhsil.com"] \
    -debug 1 -usetls 0
}