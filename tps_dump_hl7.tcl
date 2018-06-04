######################################################################
# Name:      tps_dump_hl7
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
# Notes:     Removes HL7 nulls from a message.
#
# History:   <date> <name> <comments>
#                 

proc tps_dump_hl7 { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "tps_remove_hl7_null/$HciConnName/$ctx" ;# Use this before every echo/puts,
    ;# it describes where the text came from

    set dispList {}                                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
            
            if { $debug } {
                puts stdout "$module: Starting in debug mode..."
            }

	    set formatdir "$::HciRoot/formats/hl7/2.3"

	    set fields [read_file "$formatdir/fields"]
	    regsub {^.*end_prologue\n} $fields "" fields
	    #echo $fields = $fields
	    foreach line [split $fields \n] {
		#set line "{$line}"
		if { $line ne "" } {
		    set allfields([keylget line ITEM]) [keylget line NAME]
		}
	    }
	    foreach file [glob "$formatdir/segments/*"] {
		set fields [read_file $file]
		regsub {^.*end_prologue\n} $fields "" fields
		#echo file = $file
		set seg [file tail $file]
		#echo seg = $seg
		set lines [split $fields \n]
		for { set i 0 } { $i < [llength $lines]-1 } { incr i } {
		    set line [lindex $lines $i]
		    #echo line = $line
		    if { $line ne "" } {
			#set allfields2([keylget line ITEM]) [keylget line NAME]
			set ::fielddesc($seg.[expr $i+1]) $allfields([keylget line ITEM])
		    }
		}
	    }
	    #parray ::fielddesc
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            
            keylget args MSGID mh
	    keylget args ARGS.TO to
            package require hl7
	    set msg [msgget $mh]
	    #set msg "MSH|^~\\&\rEVN|foo\r"
	    set hl7 [hl7::parse_msg $msg]
	    set msg "<table border=1>\n"

	    set seg_count [hl7::count hl7 ""]
	    array unset counts

	    for { set f1 1 } { $f1 <= $seg_count } { incr f1 } {
		set segname [hl7::get_field hl7 $f1.[expr 0]]
		#echo segname = $segname
		if { ![info exists counts($segname)] } {
		    set counts($segname) 0
		}
		set segno [incr counts($segname)]
		set fullseg "${segname}($segno)"
		#echo segname = $fullseg
		set field_count [hl7::count hl7 $fullseg]
		if { $segname eq "MSH" } {
		    set last_field [expr $field_count + 1]
		} else {
		    set last_field $field_count
		}
		for { set j 0 } { $j <= $last_field } { incr j } {
# 		    if { $segname eq "MSH" && $j == 0 } {
# 			continue
# 		    }
		    set f2 "$fullseg.$j"
		    set rep_field_count [hl7::count hl7 $f2]
# 		    if { $rep_field_count < 1 } {
# 			set rep_field_count 1
# 		    }
		    for { set k 1 } { $k <= $rep_field_count } { incr k } {
			set f3 "${f2}($k)"

			# put all encoding characters in one field
			if { $f2 eq "MSH(1).2" } {
			    if { $k > 1 } {
				continue
			    }
			    set f3 $f2
			}

			set comp_count [hl7::count hl7 $f3]
			set val [hl7::get_field hl7 $f3]
			#puts "$f5: $val"
			set desc ""
			if { [info exists ::fielddesc($segname.$j)] } {
			    set desc $::fielddesc($segname.$j)
			}
			append msg [format "<tr><td>%s</td><td>%s</td><td>%s</td></tr>\n" $f3 $desc $val]
		    }
		}
	    }
	    append msg "</table>\n"
	    set userdata {}
	    keylset userdata SUBJECT "[hl7::get_field hl7 MSH.9] for [hl7::get_field hl7 PID.5]"
	    keylset userdata CONTENT_TYPE text/html
	    keylset userdata TO $to
	    msgmetaset $mh USERDATA $userdata

	    msgset $mh "$msg"
	    #msgset $mh [hl7::join_msg hl7]
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
