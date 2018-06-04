#!/usr/bin/env tcl
# SQLite Documentation Procs
# 04/26/2017 - Jones - Created

# Sets up SQL Lite Documentation Database and tables for storing cloverleaf documentation items.

proc refreshDB { path fileName {debug 0} } {
	# Creates the appropriate SQLite file. If file exists, it will remove the file deleting all data
	# Args:
	#		path - path where file will be stored (/hci/cis6.1/integrator/sqlite_tables/)
	#		fileName - Name of new SQLite file (sqlDoc)
	#
	# USE WITH CAUTION
	
	# Check for file existence
	if { [file exists $path/$fileName.db] } {
		# Remove the existing file
		file delete $path/$fileName.db
	}
	
	# Creates the file and then closes it
	sqlite3 rDB $path/$fileName.db
	
	rDB close;
	
	return 1
}

proc createTables { fileName {debug 0} } {
	# Creates the documentation tables
	# Args:
	#		fileName - the db file	
	#		debug - 
	# Returns:
	#		List of all tables in the db.
	
	# Check for file existence
	if { ![file exists $fileName] } {
		# File doesn't exist. We out
		puts "File does not exist. Try refreshing the db or create the file manually."
		return -1
	}
	
	# Setup the db handle
	sqlite3 rDB $fileName
	# Create the table with the columns
	# Sets up the db Tables that we will be using.
	
	# Added test table and sites table - Jones - 04/26/2017
	
	rDB eval {CREATE TABLE test(name text)}
	rDB eval {CREATE TABLE sites(name text, path text)}
	rDB eval {CREATE TABLE processes(site int, name text)}
	rDB eval {CREATE TABLE threads(process int, name text, notes text)}
	rDB eval {CREATE TABLE xlates(site int, fileName text)}

	# Get a list of the tables
	set tables [rDB eval {SELECT name from sqlite_master WHERE type='table'}]
	rDB close;
	
	return $tables
}

proc getProcesses { fileName {debug 0}} {
	# Inserts or Updates every process 
	# Args:
	#		fileName - the db file		
	#		debug - 
	# Returns:
	#		Record Count for the table
	
	global HciRoot
	# Check for file existence
	if { ![file exists $fileName] } {
		# File doesn't exist. We out
		puts "File does not exist. Try refreshing the db or create the file manually."
		return -1
	}
	
	# Setup the db handle
	sqlite3 rDB $fileName
	
	# Traverse the sites and 
	
	return 1
}

# Uncomment to refresh the sqlDocs db file. WILL DELETE FILE AND REINIT
refreshDB "/hci/cis6.1/integrator/sqlite_tables" "sqlDoc"
puts [createTables "/hci/cis6.1/integrator/sqlite_tables/sqlDoc.db" ]

set fileName "/hci/cis6.1/integrator/sqlite_tables/sqlDoc.db"

global HciRoot
# Check for file existence
if { ![file exists $fileName] } {
	# File doesn't exist. We out
	puts "File does not exist. Try refreshing the db or create the file manually."
	return -1
}

# Iterate over the sites and add query the sqlite db for the site.
# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]
# set siteNum 1; set procNum 1; set connNum 1; set xNum 1;
# puts "sites: $sites"
foreach path $sites {

	if {![file isdirectory $path]} {
	  continue 
	}
	
	# Setup the db handle
	sqlite3 rDB $fileName
	
	set site [file tail $path]
	# Do a look up of the site name:
	netcfgLoad $HciRoot/$site/NetConfig
	# set cond {WHERE name = $site}
	set siteFlag [rDB eval {SELECT rowid FROM sites WHERE name=$site}]
	
	if { $siteFlag != "" } {
		# Site is in the table. Update it.
		rDB eval {UPDATE sites set name=$site, path=$path WHERE rowid=$siteFlag}
		
		puts "Site Updated: $site"
	} else {
		# Site is not in the table. Add it
		rDB eval {INSERT INTO sites VALUES($site, $path)}
		
		puts "Site added: $site"
		set siteFlag [rDB eval {SELECT rowid FROM sites WHERE name=$site}]
		# incr siteNum
		
	}
	
	puts "SiteFlag: $siteFlag"
	
	# Get Processes
	set procList [lsort [netcfgGetProcList]]
	
	foreach proc $procList {
		set procFlag [rDB eval {SELECT rowid FROM processes WHERE name=$proc AND site=$siteFlag}]
		puts "proc: $proc"
		puts "procFlag: $procFlag"
		
		if { $procFlag != "" } {
			# Process exists. Update
			rDB eval {UPDATE processes set name=$proc, site=$siteFlag}
			
			puts "Process updated: $proc"
		} else {
			#Process not in the table. Add it.
			rDB eval {INSERT INTO processes VALUES($siteFlag, $proc)}
			
			puts "Process added: $proc"
			set procFlag [rDB eval {SELECT rowid FROM processes WHERE name=$proc AND site=$siteFlag}]
			# incr procNum
		}
		puts "procFlag: $procFlag"
		
		
		# Get Threads
		set connList [lsort [netcfgGetProcConns $proc]]
		foreach conn $connList {
			puts "conn: $conn"
			set connFlag [rDB eval {SELECT rowid FROM threads WHERE name=$conn AND process=$procFlag}]
			# Get the notes for the thread.
			set noteDir "$HciRoot/$site/notes/NetConfig/$proc/"
			set note ""; set noteFile [concat $noteDir thread_$conn.notes ]
			regsub -all {\s} $noteFile {} noteFile
			set note ""
			if {[file exists $noteFile]} {
				catch {exec cat $noteFile} note
			}
			puts "connFlag: $connFlag"
			
			if { $connFlag != "" } {
				# tthread exists. Update
				rDB eval {UPDATE threads set name=$conn, process=$procFlag, notes=$note}
				
				puts "Thread updated: $conn"
			} else {
				#Process not in the table. Add it.
				rDB eval {INSERT INTO threads VALUES($procFlag, $conn, $note)}
				
				puts "Thread added: $conn"
				set connFlag [rDB eval {SELECT rowid FROM threads WHERE name=$conn AND process=$procFlag}]
				# incr connNum
			}
		}
	}
	
	return 0
	
	# Get Xlates
	# Traverse the Xlate directory and add each file to a table. This table will hold the filename and the site that the xlate lives in.
	catch {exec ls -l $path/Xlate | awk {{ print $9 }} } listing options
	
	foreach xlate $listing {
		# Check for the existence of the xlate
		set xFlag [rDB eval {SELECT rowid FROM xlates WHERE fileName=$xlate AND site=$siteFlag}]
		
		if { $xFlag != "" } {
			# Xlate exists. Update
			rDB eval {UPDATE xlates set fileName=$xlate, site=$siteFlag}
			
			puts "Xlate Updated: $xlate"
		} else {
			# Xlate is not in the table. Add it
			rDB eval {INSERT INTO xlates VALUES $siteFlag, $xlate)}
			
			puts "xlate added: $xlate"
			set xFlag [rDB eval {SELECT rowid FROM xlates WHERE fileName=$xlate AND site=$siteFlag}]
			# incr xNum
		}
	}	

	
	# Get Variants
	
	# Get Tcl Procs
	
	rDB close;

}
