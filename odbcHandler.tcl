###############################################################################
# Name:			odbcHandler.tcl
# Author:		Justin Jones
# Date:	 		04/15/2015
# Purpose:	Generic odbc Handler
# Args: 	
#           server  - The server name from the odbc.ini file
#           sqlstmt - Name of the file to write to
#		
#
# Returns: 	list of result rows
# USAGE: 		odbcHandler <DSN Name from odbc.ini> <SQL Statement> <Debug Value> <Query Timeout Value>
# Example: 	set result [odbcHandler "ILXDB-CIE01" "SELECT TOP 5 * FROM dbo.msgArchiveMetaT m WHERE m.msgAccountNum = 'Y00007102677';" $debug]
# TODO: 	 	Return more information..
#
###############################################################################

proc odbcHandler { DSN user pass sqlstmt {debug 0} {timeoutQ 25} } {
  
  package require odbc
	global HciRoot 
	
	# Debug val for getting further error messages...
	set module "odbcHandler"
	# comment debug back out when done
	#set debug 3
	# Sets a "message handle" that will hold error data and debug information and return values.
	set mh ""
	
	# Parse ODBC.ini file to find the user and password for the supplied DSN value
	# This was causing core dumps in the CAC site...Going to hardcode the values for now...
#	if {[file exists "$HciRoot/lib/Connect7.0/odbc.ini"]} {
#		set odbcFile [open "$HciRoot/lib/Connect7.0/odbc.ini"]
#		fconfigure $odbcFile -translation binary
#		set data [read $odbcFile]
#		close $odbcFile
#	} else {
#		set errMsg "odbc.ini file not found. File should be located at $HciRoot/lib/Connect7.0/ . Please check the location and try again."
#		puts $errMsg
#		set mh "$module odbc.ini file not found. File should be located at $HciRoot/lib/Connect7.0/ . Please check the location and try again."
#		set returnList {} ; lappend returnList "SQL_Error" ; lappend returnList "$mh"; return $returnList
#	}
#	
#	# Set the DNS index as the place in the file data that holds our DNS name
#	set dsnIndex [lsearch -regexp $data $DSN\] ]
#	#puts "$module - dsnIndex: $dsnIndex"
#	
#	if { [string equal $dsnIndex -1] } {
#		set mh "$module odbc.ini parsing: Cannot find supplied DSN. Please check the entry and try again."
#		set returnList {} ; lappend returnList "SQL_Error" ; lappend returnList "$mh"; return $returnList	
#	} else {
#		# Grab a range starting from our DSN entry
#		set range [lrange $data $dsnIndex end]
#		# Grab the next occurrence of LogonID= and Password=
#		set user [lindex $range [lsearch -regexp $range "LogonID\="]]
#		set user [lindex [split $user =] 1]
#		set pass [lindex $range [lsearch -regexp $range "Password\="]]
#		set pass [lindex [split $pass "="] 1]
#	}
	
	if {$debug > 1} {echo "$module Username: $user , Password: $pass"}
	
	# Make ODBC Connection
	# init ODBC Environment
	set result [odbc SQLAllocHandle SQL_HANDLE_ENV SQL_NULL_HANDLE henv]
	if {$debug > 1} {echo "$module SQLAllocHandle ODBC result: $result"}
	if {$result eq "SQL_ERROR"} {
		set mh "$module SQLAllocHandle (ENV) ODBC result: $result - check ODBC installation"
		set returnList {} ; lappend returnList "SQL_ERROR" ; lappend returnList "$mh"; return $returnList
	}
	
	# Set the most current ODBC version (3.0)
	set result [odbc SQLSetEnvAttr $henv SQL_ATTR_ODBC_VERSION SQL_OV_ODBC3 0]
	if {$debug > 1} {echo "$module SQLSetEnvAttr result: $result"}
	if {$result eq "SQL_ERROR"} {
	    catch {odbc SQLFreeHandle SQL_HANDLE_ENV $henv}
	    set mh "$module SQLSetEnvAttr ODBC result: $result - check ODBC installation"
	    set returnList {} ; lappend returnList "SQL_ERROR" ; lappend returnList "$mh"; return $returnList
	}
	
	# Allocate connection Handle
	set result [odbc SQLAllocHandle SQL_HANDLE_DBC $henv hdbc]
	if {$debug > 1} {echo "$module SQLAllocHandle CONN result: $result"}
	if {$result eq "SQL_ERROR"} {
	    catch {odbc SQLFreeHandle SQL_HANDLE_ENV $henv}
	    set mh "$module SQLAllocHandle (DBC) ODBC result: $result - check ODBC installation"
	    set returnList {} ; lappend returnList "SQL_ERROR" ; lappend returnList "$mh"; return $returnList
	}
	
	# Set the connection timeout
	set timeoutC 30
	set result [odbc SQLSetConnectAttr $hdbc SQL_ATTR_LOGIN_TIMEOUT $timeoutC 5]
	if {$debug > 1} {echo "$module SQLSetConnectAttr Login Timeout result: $result"}
	if {$result eq "SQL_ERROR"} {
	    catch {odbc SQLFreeHandle SQL_HANDLE_DBC $hdbc}
	    catch {odbc SQLFreeHandle SQL_HANDLE_ENV $henv}
	    set mh "$module SQLSetConnectAttr (TIMEOUT LOGIN) ODBC result: $result - check ODBC installation"
	    set returnList {} ; lappend returnList "SQL_ERROR" ; lappend returnList "$mh"; return $returnList
	}
	
	# Make the connection
	
	set result [odbc SQLConnect $hdbc $DSN SQL_NTS $user SQL_NTS $pass SQL_NTS]
	#set result [odbc SQLDriverConnect $hdbc NULL $connstr $lconnstr NULL NULL NULL SQL_DRIVER_NOPROMPT]
	if {$debug > 1} {echo "$module SQLConnect result: $result"}
	if {$result eq "SQL_ERROR"} {
	    set retcode [odbc SQLGetDiagRec SQL_HANDLE_DBC $hdbc 1 SQLState NativeError MessageText 1024 TextLength]
	    if {$debug < 2} {echo "$module SQLConnect result: $result"}
	    set mh "$module sqlstate: $SQLState error: $NativeError text: $MessageText"
	    catch {odbc SQLFreeHandle SQL_HANDLE_DBC $hdbc}
	    catch {odbc SQLFreeHandle SQL_HANDLE_ENV $henv}
	    set returnList {} ; lappend returnList "SQL_ERROR" ; lappend returnList "$mh"; lappend returnList "$SQLState"
	    lappend returnList "$SQLState"; return $returnList
	} 
	
	# Freeing the previous handle and allocating a new statement handle
	catch {odbc SQLFreeStmt $hstmt SQL_DROP}
	set result [odbc SQLAllocHandle SQL_HANDLE_STMT $hdbc hstmt]
	if {$debug > 1} {echo "$module SQLAllocHandle result: $result"}
	if {$result eq "SQL_ERROR"} {
	    catch {odbc SQLFreeHandle SQL_HANDLE_DBC $hdbc}
	    catch {odbc SQLFreeHandle SQL_HANDLE_ENV $henv}
	    set mh "$module SQLAllocHandle (STMT) ODBC result: $result - check SQL Server"
	    set returnList {} ; lappend returnList "SQL_ERROR" ; lappend returnList "$mh"; return $returnList
	} 
	
	# Set a query timeout - Originally set to 25 seconds. Had to update to accomodate bulk inserting.  The current value sets NO timeout
	# The timeoutQ value is passed as a parameter when needed. We have set a default at the beginning of the script
	# set timeoutQ 1
	set result [odbc SQLSetStmtAttr $hstmt SQL_ATTR_QUERY_TIMEOUT $timeoutQ 1]
	if {$debug > 1} {echo "$module SQLSetStmtAttr QueryTimeout result: $result"}
	

	if {$debug > 2} {echo  "$module sqlstmt: $sqlstmt"}
	
	# Execute the SQL
	set result [odbc SQLExecDirect $hstmt $sqlstmt SQL_NTS]
	if {$debug > 1} {echo "$module SQLExecDirect result: $result"}
	if {$result ne "SQL_SUCCESS"} {
	    set retcode [odbc SQLGetDiagRec SQL_HANDLE_STMT $hstmt 1 SQLState NativeError MessageText 511 TextLength]
	    # set mh "$module SP executed - result: $result"
	    set mh "$module sqlstate: $SQLState error: $NativeError text: $MessageText"
	    set returnList {} ; lappend returnList "SQL_ERROR" ; lappend returnList "$mh"; return $returnList
	}
	
  # First, get a count of the number of columns in the result set.
	set result [odbc SQLNumResultCols $hstmt numColumns]
	if {$debug > 1} {echo "$module SQLNumResultcols result: $result - NumColumns: $numColumns"}
	if {$result eq "SQL_ERROR"} {
			set retcode [odbc SQLGetDiagRec SQL_HANDLE_STMT $hstmt 1 SQLState NativeError MessageText 511 TextLength]
	    puts "$module SQLNumResultCols - result: $result"
	    puts "$module sqlstate: $SQLState error: $NativeError text: $MessageText"
	    set mh "$module SQLNumResultCols ODBC result: $result "
	    set returnList {} ; lappend returnList "SQL_ERROR" ; lappend returnList "$mh"; return $returnList 
	}
 
  # Next We must iterate over the number of columns that are present in the result set.
  set i 1
  set fieldList ""
  set pcbList ""
  set valueList ""
  set returnList ""
  
  while {$i <= $numColumns} { 
  	# Get each Column and it's details
  	set result [odbc SQLDescribeCol $hstmt $i colName 255 colNameLen colType colSize colDigits colNull]
  	# lappend fieldList [list $colName $colType $colSize]
  	if {$debug > 1} {puts "$module SQLDescribeCol result: $result" }
  	if {$result eq "SQL_ERROR"} {
  		set retcode [odbc SQLGetDiagRec SQL_HANDLE_STMT $hstmt 1 SQLState NativeError MessageText 511 TextLength]
	    echo "$module SQLDescribeCol - result: $result"
	    echo "$module sqlstate: $SQLState error: $NativeError text: $MessageText"
	    set mh "$module SQLDescribeCol ODBC result: $result "
	    set returnList {} ; lappend returnList "SQL_ERROR" ; lappend returnList "$mh"; return $returnList 
  	}
  	
  	if {$colSize > 500000} {
      set colSize 1073741825
   	}
   	if {$colSize < 32} {
      set colSize 32
   	}
   	# set colSize 255
  	set pcbValue "pcb$i"  
		set colValue "cval$i"
		# puts "ColSize: $colSize"
  	# Bind the column. This must be done to set the row results to a var.
  	if {$colType eq ""} { set colType SQL_C_CHAR }
  	set result [odbc SQLBindCol $hstmt $i SQL_C_CHAR $colValue $colSize $pcbValue]
  	if {$debug > 1} {puts "$module Result Iteration Step $i result: $result" }
  	if {$result eq "SQL_ERROR"} {
  		set retcode [odbc SQLGetDiagRec SQL_HANDLE_STMT $hstmt 1 SQLState NativeError MessageText 511 TextLength]
	    echo "$module SQLBindCols - result: $result"
	    echo "$module sqlstate: $SQLState error: $NativeError text: $MessageText"
	    set mh "$module SQLBindCol ODBC result: $result "
	    set returnList {} ; lappend returnList "SQL_ERROR" ; lappend returnList "$mh"; return $returnList  
	  }
  	lappend fieldList $colName
  	lappend pcbList $pcbValue
  	lappend valueList $colValue
  	incr i
  }

  # Now fetch the data row by row
  set rowCount 0
  
  # set result [odbc SQLFetch $hstmt]
  set rowList ""
  set result [odbc SQLFetch $hstmt]
  while { $result == "SQL_SUCCESS" || $result == "SQL_SUCCESS_WITH_INFO" } {
  	set i 0
  	set rowValues ""
  	
  	# Get all column values for the row
  	while {$i < $numColumns} {
  		set key ""
  		set field ""
  		set fieldLength [eval set len_value "$[lindex $pcbList $i]"]
  		if { $fieldLength eq "SQL_NULL_DATA" } {
  			if {$debug > 1} {puts "SQL_NULL_DATA"}
  		} else {
	  		set key [lindex $fieldList $i]
	  		set field [eval set fld_value "$[lindex $valueList $i]"]
	  	}
	  	lappend rowValues $field
	  	incr i
  	}
  	lappend returnList $rowValues
  	
  	set result [odbc SQLFetch $hstmt]
  	incr rowCount
  	
  	if {$result eq "SQL_ERROR"} {
  		set retcode [odbc SQLGetDiagRec SQL_HANDLE_STMT $hstmt 1 SQLState NativeError MessageText 511 TextLength]
	    puts "$module SQLFetch - result: $result, rowcount: $rowCount"
	    puts "$module sqlstate: $SQLState error: $NativeError text: $MessageText"
	    set mh "$module SQLFetch ODBC result: $result "
	    set returnList {} ; lappend returnList "SQL_ERROR" ; lappend returnList "$mh"; return $returnList  
  	}
  	
  }
  if {$debug > 1} {puts "$module - RowCount: $rowCount"}
  if {$debug > 1} {puts "$module SQLFetch Finished Return List: $returnList"}
	
	# clean up SQL and exit tcl
	catch {odbc SQLFreeStmt $hstmt SQL_DROP}
	catch {odbc SQLDisconnect $hdbc}
	catch {odbc SQLFreeHandle SQL_HANDLE_DBC $hdbc}
	catch {odbc SQLFreeHandle SQL_HANDLE_ENV $henv}

	# Return some stuff!
  return $returnList
}