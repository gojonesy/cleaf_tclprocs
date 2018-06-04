#!/usr/bin/env tcl
#
# Copyright (c) 2015, Infor, All rights reserved.
#
# Author: Charlie Bursell
#   Date: 07/30/15
#
#  A redo of the hcismat script for SMAT DB
#  Most flags and execution remain the same except for site option
#  Site is needed for database encryption key 
#  Default is current site
#
#  Also added an option to specify inbound or outbout thread
#  Needed for resending messages pre or post tps
#  Default is ob_post_tps
#
#  It would be wise to copy an active, still in use, DB to another
#  file prior to running this
#
#  A lot of error checking is done and the script will exit if
#  something is wrong.  However I can't presuppose every possible
#  error.  If you get weird results, take a look at the usage.
#
#  Run the script with no arguments to see the usage statement
#
#  Feel free to modify as you see fit but I would appreciate it
#  if you would give the script a different name and remove my
#  name as the author.  I take credit for my screw ups but not
#  for others  :-)
#
#  Assumes Tcl 8.5+
#
proc hcismatdb {argv} {

    # Get name of command executed
    set SMAT::myName [file rootname [file tail $::argv0]]

    # Get command line arguments and do some validation
    SMAT::getArgs $argv

    # Select the wanted messages either selected or unselected
    SMAT::selectMsgs

    # Perform the indicated Operation
    SMAT::performOP

    # All done
    return ""
}

namespace eval SMAT {

    # All of the heavy lifting is done in the namespace

    # Name of command - for error messages
    set myName ""

    # Default site name for encrypted DB
    set SITE $::HciSite

    # Need the package
    package require sqlite

    # We stote start, end date in shared variables
    set DTSTART ""	;# Start date/time
    set DTEND ""	;# End date/time

    # Same with MID values
    set MIDSTART ""	;# Start of MID
    set MIDEND ""	;# End of MID

    # Basic query - other conditions to be added as requesred
    set DBQUERY {SELECT MessageContent FROM smat_msgs}

    # Query if unselected messages wanted
    set USELECT {"$DBQUERY WHERE MessageContent NOT in ($DBQUERY)"}

    # is this windows?
    set isWin 0
    if {[string toupper $::tcl_platform(platform)] eq "WINDOWS"} {
	set isWin 1
    }

    # List of arguments for the getopts call
    set optargs [list \
        {site   1 TARGET {::SMAT::checkSite}} \
        {orst   1 TARGET {::SMAT::checkTarget}} \
        {orut   1 TARGET {::SMAT::checkTarget}} \
        {orsf   1 TARGET {::SMAT::checkTarget}} \
        {oruf   1 TARGET {::SMAT::checkTarget}} \
        {pri    1 PRIORITY {::SMAT::checkPriority}} \
        {sds    1 DTSTART {::SMAT::checkDate}} \
        {sde    1 DTEND {::SMAT::checkDate}} \
        {sdn    f NOTDT} \
        {sms    1 MIDSTART {::SMAT::checkMid}} \
        {sme    1 MIDEND   {::SMAT::checkMid}} \
        {smn    f NOTMID} \
        {sall   f SALL} \
        {reply  f REPLY} \
        {ib     f IB} \
        {thd    1 THD {::SMAT::checkThread}} \
        {i      1 SMATFILE {::SMAT::validateDB}} \
        {nl     f NL} \
    ]

    # Usage statement
    set USAGE {

usage: $myName -i filename <operation> ?-pri priority? ?-nl?\
			 ?-reply? ?-ib? <message selection criteria>
where:
    -i <DB name>        Name of SMAT DB - required Need full path if not in current dir
    -site <sitename>	Name of site in current root Optional dfault current site
    -pri <priority>     Resend priority	 (4096 - 8192) Default = 5120
    -reply              Resend selected messages as reply instead of data
    -ib                 Resend messages pre_tps instead of post_tps (Default=post_tps)
    -thd <in/out>       Resend messages to IB or OB thread (Default=OB)
    -nl			Write file as newline delimited, default is len10
<operation> is exactly one of:
    -orsf <filename>    Resend selected messages to file <filename>
    -oruf <filename>    Resend unselected messages to file <filename>
    -orst <thread>      Resend selected messages to thread <thread>
    -orst <thread>      Resend unselected messages to thread <thread>
<message selection criteria> is any valid grouping of:
    -sds <date>         Starting at date and time <date> yyyymmdd[hhmmss]
    -sde <date>         Ending at date and time <date>   yyyymmdd[hhmmss]
    -sdn                Not meaning of date search
    -sms <mid>          Starting at message id <mid>	[0.0.]###
    -sme <mid>          Ending at message id <mid>	[0.0.]###
    -smn                Not meaning of mid search
    -sall               Select all messages in input file - default if no other selection}

    # Initialize the argArray - used throughout
    array set argArray {
	SELECT 0
	TARGET ""
	OPERATION ""
	FILE 0
	PROCESS ""
	PRIORITY 5120
	REPLY 0
	IB 0
	THD OUT
	SALL ""
	NOTDT 0
	DTSTART ""
	DTEND ""
	NOTMID 0
	MIDSTART ""
	MIDEND ""
	NL 0
	SMATFILE ""
    }
    
    # List of argArray keys
    set arrayKeys [list SELECT TARGET OPERATION FILE PROCESS PRIORITY REPLY]
    lappend arrayKeys IB SALL NOTDT DTSTART DTEND NOTMID MIDSTART MIDEND NL

    ############################################################################
    # getArgs - Get command line args
    #
    # Usage: getArgs <argsList>
    #		argsList = List of command line arguments (argv)
    #
    # Notes: Just call getopt.  Most of parsing in done in validargs
    #
    # Returns: nothing
    ############################################################################
    proc getArgs {optlist} {
	variable optargs	;# The options list for getopt
	variable USAGE		;# Usage statement
	variable myName		;# Name of main procedure
	variable argArray	;# Argument array
	variable arrayKeys	;# List of array keys

	# If no arguments show usage
	if {$optlist eq ""} {

	    puts stderr "\n[subst -nocommands $USAGE]\n"
	    exit 64

	}

	# If Site argument is passed it must be done first
	# in case we need to open the DB
	set loc [lsearch -regexp [string tolower $optlist] {^-site}]

	# If not first make it so
	if {$loc > 0} {
	    # Get -site
	    set x [lvarpop optlist $loc]

	    # Get site name
	    set y [lvarpop optlist $loc]

	    # Make them first in list
	    set optlist [linsert $optlist 0 $x $y]
	}


	# Run getopt to parse arguments
	if { [catch {getopt $optlist $optargs} err] } {
	    puts stderr "\n$myName: Invalid argument $err\n"
	    puts stderr [subst -nocommands $USAGE]
	    exit -64
	}

	# Reset argArray as needed
	foreach key $arrayKeys {

	    if {[info exists $key]} {set argArray($key) [set $key]}
	}

	# Need at least one operation orsf, oruf, orst or orut
	if {$argArray(TARGET) eq ""} {

	    puts stderr "\n$myName: One of -orut, -oruf,\
		-orst or -orsf is required!\n"
	    puts stderr [subst -nocommands $USAGE]
	    exit -64
	}

	# Set Default Priority if empty
	if {$argArray(PRIORITY) eq ""} {set argArray(PRIORITY) 5120}

	# All done
	return ""
    }

    ############################################################################
    # validateDB - Validates that file name is a valid SMAT sqlite file
    #
    # Usage: validDB args
    #		args = list of arguments passed by getopt command
    #
    # Notes: Validates DB file then opens if valid
    #	     Opens with name handle "DB" which will be available throughout
    #	     the script
    #
    #	     Must be careful not to open non-existent file as sqlite will
    #	     create it if it does not exist
    #	
    #	     Unecrypted sqlite files are easy as the begin with the characters
    #        "sqlite".  Encrypted is a bit tougher
    #
    #	     Must be careful when issuing a PRAGMA statement if we think DB
    #	     is encrypted.  If it is sqlite and not encrypted we just made it so
    #
    # returns: nothing - exit if error
    ############################################################################
    proc validateDB {args} {

	variable myName		;# main procedure name
	variable USAGE		;# USAGE statement
	variable SITE		;# Site name

	# Get SMAT DB into DSN
	set DSN [lindex [lindex $args 1] 0]

	# Make sure not empty
	if {[string trim $DSN] eq ""} {
	    puts stderr "\n$myName: SMAT DB $DSN is required!\n"
	    puts stderr [subst -nocommands $USAGE]
	    exit -64
	}

	# See if file even exists abd is regular file
	if {![file isfile $DSN]} {
	    puts stderr "\n$myName: SMAT DB $DSN does not exist or not regular file!\n"
	    puts stderr [subst -nocommands $USAGE]
	    exit -64
	}

	# Test for unencrypted sqlite - First 6 bytes = sqlite
	if {[catch {open $DSN rb} fd]} {
	    puts stderr "\n$myName: Cannot open $DSN\n"
	    exit -64
	}

	# Read first 6 bytes.  If unencrypted sqlite s/b "SQLite"
	if {[string toupper [read $fd 6]] eq "SQLITE"} {

	    set encrypt 0
	} else {

	    # Assume encrypted
	    set encrypt 1
	}

	# Close the file
	close $fd

	# Assume it is sqlite and open as such
	sqlite DB $DSN

	# If suspect encrypted issue PRAGMA
	if {$encrypt} {DB eval "PRAGMA KEY='$SITE'"}

	# Query for tables get names to see if SMAT DB
	if {[catch { DB eval "SELECT name FROM sqlite_master WHERE type='table'"} rslt]} {

	    DB close
	    puts stderr "\n$myName: Cannot query $DSN as SMAT DB - $rslt\n"

	    if {$encrypt} {
		puts stderr "Make sure site name is correct for this SMAT DB!\n"
	    }

	    exit -64
	}

	# Validate it is SMAT by schecking for smat_msgs table
	if {![regexp -nocase -- {smat_msgs} $rslt]} {

	    DB close
	    puts stderr "\n$myName: $DSN is sqlite but does not seem to be a SMAT DB file!\n"

	    exit -64
	}

	# If here, all is OK
	return ""
    }

    ############################################################################
    # checkSite - Checks site and set default if needed
    #
    # Usage: checkSite args
    #		args = List arguments passed by getopt command
    #
    # Notes: Called everytime the argument site is passed
    #	     overrides default if valid
    #
    #	     Store site name in shared variable SITE
    #	
    #
    # returns: nothing
    ############################################################################
    proc checkSite {args} {

	variable myName		;# main procedure name
	variable argArray	;# array of arguments
	variable USAGE		;# USAGE statement
	variable SITE		;# Site name

	# Get Site name from args
	set SITE [lindex $args 1]
	
	# Validate
	# Get the root path
	set root $::HciRoot

	# Read server.ini file
	if {[catch {read_file -nonewline [file join $root server server.ini]} ini]} {

	    puts stderr "\n$myName: Cannot open server.ini: $ini\n"
	    exit -64
	}

	# Get env
	if {![regexp -line -- {^environs=(.*?)$} $ini {} envStr]} {

	    puts stderr "\n$myName: Cannot find environs list in server.ini\n"
	    exit -64
	}

	# Look for site - Assume not found
	set found 0

	foreach site [split $envStr ";"] {

	    # If site is found set flag and exit loop
	    if {[file tail $site] eq $SITE} { set found 1 ; break }
	}

       # If site not in server.ini tell em

       if {!$found} {
	   puts stderr "\n$myName: $SITE not found in server.ini !\n"
	   exit -64
       }

       # All is OK
       return ""
    }

    ############################################################################
    # checkTarget - Makes sure only one Operation
    #
    # Usage: checkTarget args
    #		args = List of arguments passed by getopt command
    #
    # Notes: Called everytime the argument orsf, orst, orut or oruf os passed
    #	     sets the operation index of argArray
    #	
    #	     If more than one operation - error
    #
    # returns: nothing
    ############################################################################
    proc checkTarget {args} {

	variable myName		;# main procedure name
	variable argArray	;# array of arguments
	variable USAGE		;# USAGE statement

	# Make sure it is first one we have seen
	# If set before something is wrong
	if {$argArray(OPERATION) ne ""} {

	    puts stderr "\n$myName: Only one of -orut, -oruf,\
		-orst or -orsf allowed!\n"
	    puts stderr [subst -nocommands $USAGE]
	    exit -64
	}

	# Set operation only once
	set argArray(OPERATION) [lindex $args 0]

	# All done
	return ""
    }

    ############################################################################
    # checkThread - Makes sure only IN or OUT is chosen
    #
    # Usage: checkThread args
    #		args = List arguments passed by getopt command
    #
    # Notes: Called everytime the argument thd is passed
    #	     sets the shared variable INOUT
    #	
    #
    # returns: nothing
    ############################################################################
    proc checkThread {args} {

	variable myName		;# main procedure name
	variable argArray	;# array of arguments
	variable USAGE		;# USAGE statement
	variable INOUT OUT	;# IB or OB thread

	set INOUT [string toupper [lindex $args 1]]

	# Must be in or out
	if {$INOUT ne "OUT" && $INOUT ne "IN"} {

	    puts stderr "\n$myName: Only in or out is allowed for option -thd\n"
	    puts stderr [subst -nocommands $USAGE]
	    exit -64
	}

	# All done
	return ""
    }

    ############################################################################
    # checkDate - makes sure date is valid - set date variables
    #
    # Usage: checkDate args
    #		args = List of arguments passed by getopt command
    #
    # Notes: Called every time the argument sds or sde is received
    #	     checks for valid date and converts to seconds.
    #	     Note if CL version 6.1+ seconds will later be converted to
    #	     milliseconds
    #
    #	     At a minimun YYYYMMDD required. For start time default time is
    #	     00:00:00.  For end time it is 23:59:59
    #	
    # Returns: nothing
    ############################################################################
    proc checkDate {args} {

	variable myName		;# main procedure name
	variable argArray	;# array of arguments
	variable USAGE		;# USAGE statement
	variable DTSTART 	;# Start Date
	variable DTEND 		;# End Date

	# Get the operation and the date
	lassign $args op date

	# Validate date - first make it scanable
	regsub -- {(\d{8})(.*)$} $date {\1 \2} scandt

	# See if valid
	if {[catch {clock scan $scandt} seconds] ||
			[string length $scandt] < 8} {

	    puts stderr "\n$myName: Invalid date: $date\n"
	    puts stderr [subst -nocommands $USAGE]
	    exit -64
	}

	# If no hours/minutes/secods
	# for start 00:00:00
	# for end 23:59:59

	# In case no time passed
	if {[llength $scandt] == 1} {lappend scandt 000000}

	set tm [lindex $scandt 1]
	set hr [string range $tm 0 1]
	set mi [string range $tm 2 3]
	set se [string range $tm 4 5]

	# Convert to seconds
	if {$op eq "sds"} {

	    if {$hr eq ""} {set hr 00}
	    if {$mi eq ""} {set mi 00}
	    if {$se eq ""} {set se 00}

	    set scandt [lreplace $scandt 1 1 "$hr$mi$se"]
	    set seconds [clock scan $scandt]
	    set DTSTART $seconds

	} else {

	    if {$hr eq ""} {set hr 23}
	    if {$mi eq ""} {set mi 59}
	    if {$se eq ""} {set se 59}
	    
	    set scandt [lreplace $scandt 1 1 "$hr$mi$se"]
	    set seconds [clock scan $scandt]
	    set DTEND $seconds
	}

	# If both start and end dates are set make sure end is after start
	
	if {$DTSTART ne "" && $DTEND ne ""} {

	    if {$DTSTART > $DTEND} {

		puts stderr "\n$myName: start date cannot\
				be greater than end date!\n"
		puts stderr [subst -nocommands $USAGE]
		exit -64
	    }
	}

	# All done
	return ""
    }

    ############################################################################
    # checkMid - makes sure MID is valid
    #
    # Usage: checkMid args
    #		args = list of arguments passed by getopt command
    #
    # Notes: Called everytime the argument sms or sme is received
    #	     checks for valid mid. in the form ###
    #	
    # returns: nothing
    ############################################################################
    proc checkMid {args} {

	variable myName		;# main procedure name
	variable argArray	;# array of arguments
	variable USAGE		;# USAGE statement
	variable MIDSTART	;# Start of MID
	variable MIDEND		;# EndStart of MID

	# get the operation and the mid
	lassign $args op mid

	# Validate mid is all numbers
	if {![string is digit -strict $mid]} {

	    puts stderr "\n$myName: Invalid MID: $mid\n"
	    puts stderr [subst -nocommands $USAGE]
	    exit -64
	}

	# Save MIDS
	if {$op eq "sms"} {
	    set MIDSTART $mid
	} else {
	    set MIDEND $mid
	}

	# iF both start and end mids are set make sure end is after start
	if {$argArray(MIDSTART) ne "" && $argArray(MIDEND) ne ""} {

	    if {$argArray(MIDSTART) > $argArray(MIDEND)} {

		puts stderr "\n$myName: Start MID cannot\
				be greater than end MID!\n"
		puts stderr [subst -nocommands $USAGE]
		exit -64
	    }
	}

	# all done
	return ""
    }

    ############################################################################
    # checkPriority - Makes sure Priority is valid
    #
    # Usage: checkPriority args
    #		args = list of arguments passed by getopt command
    #
    # notes: Called everytime the argument pri is received
    #	     checks for valid Priority. numerical and range
    #	     4096 - 8192 Default = 5120
    #	
    # Returns: Nothing
    ############################################################################
    proc checkPriority {args} {

	variable myName		;# Main procedure name
	variable argArray	;# Array of arguments
	variable USAGE		;# Usage statement

	# Get the Priority
	set pri [lindex $args 1]

	# Validate
	if {![string is digit -strict $pri] || $pri < 4096 || $pri > 8192} {

	    puts stderr "\n$myName: Invalid priority: $pri.\
	    		Must be 4096 - 8192\n"
			
	    puts stderr [subst -nocommands $USAGE]
	    exit -64
	}

	# All done
	return ""
    }

    ##########################################################################
    # selectMsgs - Select wanted messages Either thos selected by query
    #		   or unselected
    #
    # selectMsgs 
    #		Uses shared variables
    #
    # Builds query to select messages from DB
    #
    # Returns: Nothing.  Set shared variables
    ##########################################################################
    proc selectMsgs {} {

	variable myName		;# Main procedure name
	variable argArray	;# Array of arguments
	variable USAGE		;# Usage statement
	variable isFile 1	;# File or thread?
	variable PROCESSNAME 	;# Process name if target is thread
	variable DBQUERY	;# Base Query
	variable USELECT	;# Query inselected messages	
	variable MSGS ""	;# List of messages
	variable DTSTART	;# Start Date
	variable DTEND		;# End Date
	variable MIDSTART	;# Start MID
	variable MIDEND		;# End MID
	variable QrySecs	;# Query for seconds
	variable QryMilli	;# Query for millisends	
	variable MSGS ""	;# List of messages meeting query


	# Other Needed flags from argArray
	foreach var [list NOTDT MIDSTART MIDEND NOTMID SALL] {

	    set $var [string trim $argArray($var)]
	}
	
	# Get the date and MID part of query
	set dtQry ""; set midQry ""

	# Cannot have SALL and DATE or MID
	if {$SALL} {

	    if {"$DTSTART$DTEND$MIDSTART$MIDEND" ne ""} {

		DB close

		puts stderr "\n$myName: Cannot specify sall flag\
				with Date or MID\n"
		puts stderr [subst -nocommands $USAGE]
		exit -64

	    }

	} 

	# Before we do all of this searching, make sure the thread
	# is available if selected

	# File or Thread. Default is file.  Check for thread
	if {[string index $argArray(OPERATION) end] eq "t"} { set isFile 0 }

	# If not file, see if thread there
	if {!$isFile} {

	    # Validate thread

	    # If no process name invalid thread
	    set PROCESSNAME [readNet $argArray(TARGET)]

	    if {$PROCESSNAME eq ""} {

		DB close

		puts stderr "\n$myName: Thread $argArray(TARGET) does not\
			exist in NetConfig"
		puts stderr "Exit ...............\n"
		exit -64
	    }
	}

	# 
	# Determine if miliseconds. CL 6.0 stores date in seconds while 6.1 stores
	# milliseconds.  Assume subsequent versions will also store in milliseconds
	# If not this will require rewrite
	# smat_info,Version in CL 6.0 is = 1.
	# So if 1, assume seconds else milliseconds

	if {"$DTSTART$DTEND" ne ""} {

	    # Flag - Assume 6.1+
	    set milliseconds 1

	    if {[catch {DB eval "SELECT Version from smat_info"} version]} {

		close DB

		puts stderr "\n$myName: Unable to get version from SAMT DB!\
			ERROR = $version"
		puts stderr "Exit ...............\n"
		exit -64
	    }

	    # If 6.0 (1) set to seconds else leave as milliseconds
	    if {$version eq "1"} { set milliseconds 0 }

	    # Makes seconds into milliseconds if needed
	    # For start set 000 for end set 999
	    if {$milliseconds} {
		if {$DTSTART ne ""} {set DTSTART ${DTSTART}000 }
		if {$DTEND ne ""} {set DTEND ${DTEND}999 }
	    }

	    # Build the date query
	    set dtQry [dateQuery $NOTDT]
	}

	# Add MID query if wanted
	if {"$MIDSTART$MIDEND" ne ""} {set midQry [midQuery $NOTMID]}

	# BUILD query
	if {$dtQry ne ""} {

	    set DBQUERY "$DBQUERY WHERE ($dtQry)"
	    if {$midQry ne ""} {append DBQUERY " AND ($midQry)"}

	} elseif {$midQry ne ""} {

	    set DBQUERY "$DBQUERY WHERE ($midQry)"
	}

	# Need a selection critera
	if {!$SALL && "$DTSTART$DTEND$MIDSTART$MIDEND" eq ""} {

	    set SALL 1
	}

	# Unselected or selected. Default is selected
	if {[string index $argArray(OPERATION) end-1] eq "u"} { 

	    # Wants unselected message
	    set DBQUERY [subst -nocommands $USELECT]
	}

	# Select messages either selected or unselected
	if {[catch {DB eval $DBQUERY} MSGS]} {

	    DB close
	    puts stderr "\n$myName: Error querying DB - $MSGS\n"
	    exit -64
	}

	DB close

	# See if success
	if {$MSGS eq ""} {

	    puts stderr "\n$myName: No messages selected!\n"
	    exit -64
	}

	puts stdout "\n$myName: [llength $MSGS] messages selected!\n"

        # All done
        return ""
    }

    ##########################################################################
    # dateQry - Build date query string
    #
    # dateQry flag
    #		Flag = 1 to negate compare
    #
    # Build the sub-query and return it
    #
    # Returns: query string
    ##########################################################################
    proc dateQuery {flag} {
	variable myName		;# Main procedure name
	variable DTSTART	;# Start date
	variable DTEND		;# End date

	# Init variables
	set st ""; set en ""

	# Start date
	if {$DTSTART ne ""} {

	    # See if negate flag set
	    if {!$flag} { 

		set st "TimeIn >= $DTSTART"

	    } else {

		set st "TimeIn < $DTSTART"
	    }
	}

	# End Date
	if {$DTEND ne ""} {

	    # See if negate flag set
	    if {!$flag} { 

		set en "TimeIn <= $DTEND"

	    } else {

		set en "TimeIn > $DTEND"
	    }
	}

	# See if both or just one set
	if {$st ne "" && $en ne ""} {

	    # Both do AND/Or based on negate flag
	    if {!$flag} {
		return "$st AND $en"

	    } else {

		return "$st OR $en"
	    }

	} elseif {$st ne ""} {

	    # Just start return that
	    return $st

	} else {

	    # Just end - return that
	    return $en
	}

	# Just in case - should never get here
	return ""
    }

    ##########################################################################
    # midQry - Build MID query string
    #
    # midQry flag
    #		Flag = 1 to negate compare
    #
    # Build the sub-query and return it
    # Similar to date query above
    #
    # Returns: query string
    ##########################################################################
    proc midQuery {flag} {
	variable myName		;# Main procedure name
	variable MIDSTART	;# Start MID
	variable MIDEND		;# End MID

	# Set variables
	set st ""; set en ""

	# Start MID?
	if {$MIDSTART ne ""} {

	    # Negate if flag set
	    if {!$flag} { 

		set st "MidNum >= $MIDSTART"

	    } else {

		set st "MidNum < $MIDSTART"
	    }
	}

	# End MID?
	if {$MIDEND ne ""} {

	    # Negate if flag set
	    if {!$flag} { 

		set en "MidNum <= $MIDEND"

	    } else {

		set en "MidNum > $MIDEND"
	    }
	}

	# If both set do AND/OR depending on negate flag
	if {$st ne "" && $en ne ""} {

	    # Negate if flag set
	    if {!$flag} {

		return "$st AND $en"

	    } else {

		return "$st OR $en"
	    }

	} elseif {$st ne ""} {

	    # If just start return that
	    return $st

	} else {

	    # If just end return that
	    return $en
	}

	# Just in case - should never be here
	return ""
    }

    #########################################################################f
    # performOP - Perform selected operation
    #
    # performOP 
    #		Uses shared variables
    #
    # Performs one of resend selected or unselected messages to a file or
    # thread.  Calls appropriate routine
    #
    # Returns: Nothing.  Set shared variables
    ##########################################################################
    proc performOP {} {

	variable isFile 	;# File or thread?

	# If file call writeFile
	if {$isFile} {

	    writeFile

	} else {

	    # if thread call writeThread
	    writeThread
	}

	return ""
    }

    ##########################################################################
    # writeFile - Write records to a file
    #
    # writeFile
    #
    # Write records, selected or unselected to specified file
    # writw as new-line or length encoded (default)
    #
    # Returns: Nothing
    ##########################################################################
    proc writeFile {} {
	variable myName		;# Name of main program
	variable argArray	;# Array of arguments
	variable MSGS		;# List of messages

	# New-line or length encoded?
	set NL $argArray(NL)

	# File name
	set fn $argArray(TARGET)

	# Catch errors - open in binary for HL7
	if {[catch {open $fn wb+} outFd]} {

            puts stderr "\n$myName: Failed to open outbound file: $fn"
            puts stderr "$outFd\n"
            exit -64
	}

	# If NL just write it out and return.  MSGS is in a list
	if {$NL} {

	    puts $outFd [join $MSGS \n]
	    close $outFd
	    return ""

	}

	# If here do length encoded
	# Get length of each record and prepend length, 10 bytes, 
	# right justified, zero filled

	foreach rec $MSGS {

	    # Record length in bytes
	    set LEN [string length $rec]

	    # Prepend length 10 bytes RJZF
	    set rec "[format %010d $LEN]$rec"

	    # Write with no newline
	    puts -nonewline $outFd $rec
	}

	# Close file
	close $outFd

	# All done
	return ""
    }

    ##########################################################################
    # writeThread - Write records to a thread if thread up and running
    #
    # writeThread 
    #
    # Write records, selected or unselected to specified thread
    #
    # Create a temporary file of nl delimited records and resend
    # On Windows us hcicmdnt.  On Unix use hcicmd
    #
    # It seems hcicmd or hcicmdnt wants us in the process directory to do this
    #
    # Returns: Nothing
    ##########################################################################
    proc writeThread {} {
	variable myName		;# Name of main program
	variable argArray	;# Array of arguments
	variable PROCESSNAME 	;# Process name if target is thread
	variable isWin		;# = 1 if Windows
	variable MSGS		;# List of messages
	variable INOUT		;# IB or OB thread

	# Thread name
	set thd $argArray(TARGET)

	# See if it looks like the process is running
	if {[catch {

			msiAttach
			set lst [msiGetStatSample $thd]

			set status "" ; keylget lst PSTATUS status
			set status [string toupper $status]

		    } err]} {

            puts stderr "\n$myName: Error reading MSI area: $err\n"
            exit -64
	}

	if {[lsearch -exact {UP INEOF TIMER} $status] < 0} {

            puts stderr "\n$myName: Thread $thd status $status\
	    		Cannot resend!\n"
            exit -64
	}

	# Build command - assume UNIX
	set cmd hcicmd

	# If windows use hcicmdnt
	if {$isWin} {set cmd hcicmdnt}

	# IB or OB thread - assume OB thread

	# Assume ob_post+tps
	set tps ob_post_tps

	# if pre tps wanted still assuming OB thread
	if {$argArray(IB)} {set tps ob_pre_tps}

	# If INBOUND thread change
	if {$INOUT eq "IN"} {
	     set tps [string map [list ob ib] $tps]
	}

	# Data or reply - Assume data
	set type data

	# Change if needed
	if {$argArray(REPLY)} {set type reply}

	# Priority
	set PRI $argArray(PRIORITY)

	# Build resend command
	set resend {[list $thd resend $tps $type $PRI $fn nl]}

	# Change to process directory.  Save current location
	set CWD [pwd]
	cd [file join $::HciProcessesDir $PROCESSNAME]

	# Temp file name
	set fn "[pid].tmp"

	# Catch errors
	if {[catch {open $fn wb} outFd]} {

            puts stderr "\n$myName: Failed to open temporary file: $fn"
            puts stderr "$outFd\n"
            exit -64
	}

	# Write to temp file
	puts $outFd [join $MSGS \n]

	# Close it
	close $outFd

	# Resend
	set res [exec $cmd -p $PROCESSNAME -c "[subst $resend]"]

	puts stdout "\n$myName: $res\n"
	puts stdout "Check the process logs for success"

	# Remove temp file
	file delete $fn

	# Return to original working dir
	cd $CWD

	return ""
    }

    ##########################################################################
    # readNet - read Netconfig and get process name
    #
    # readNet  <thread>
    #		thread = thread name to get process name
    #
    # Read the site NetConfig file find thread and get process name
    #
    # Returns: Process name or empty string if not found
    ##########################################################################
    proc readNet {thread} {
	variable myName		;# Name of main program


        # Load the NetConfig

        # This is not really needed as default is to read site NetConfig
        set Net [file join $::HciSiteDir NetConfig]

        if {![netcfgLoad $Net]} {

            puts stderr "\n$myName: Failed to read NetConfig file"
            puts stderr "Exit ...............\n"
            exit -64
        }

        # List of Threads
        set connList [netcfgGetConnList]

	# If thread not found return empty string
	if {[lsearch -exact $connList $thread] < 0} { return "" }

        # Get connection data for thread
        set thdData [netcfgGetConnData $thread]

	# Get process name
	set proc "" ; keylget thdData PROCESSNAME proc

        # All done
        return $proc
    }
}

set argv [string map [list \\ / ] $argv]
hcismatdb $argv

