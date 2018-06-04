############################################################################################
#	File:	Cloverleaf_Archive.tcl							   #
#	Initial Release:	Tue Aug 23 12::00:00 2016				   #
#											   #
#	Last Modified:									   #
#											   #
#	1.1	08/23/2016	Mike Keys	Initial relase				   #
#											   #
############################################################################################
############################################################################################
# Name:		Cloverleaf_Archive.tcl
# Author:		Mike Keys
# Purpose:		Extracts all threads associated with Arg <process>.
#			Cycles save message files, then
#			looks for any files in LogHistory or SmatHistory folders, parses the
#			datestamp and moves them to a subdirectory with the appropriate date.
#			Dir name is in MMM_DD style (ie Jun_23).
#			The number of days to retain files <max files> is user defined.
#			NOTE: This program is really designed to be run ONCE in a
#			24 hour period.
# UPoC type:	tps
# Args:		ARGS    user-supplied arguments:
#			Required {process name to locate saved messages directory}
#			Required {max number of days to retain cycled saved messages}
#			Optional {directory in which to place cycled saved messages directories}
#
########################################################
#  Check for correct number of command line arguments  #
########################################################

	if {$argc < 2} {
		echo {
			Usage: Cloverleaf_Archive.tcl   <process> <max days> <backup dir> <restart site daemons> <restart processes>
			process  = name of site executing the saved message thread
			max days  = max number of days to retain cycled saved messages
			backup dir= directory where the backup files belong
			restart site daemons = Yes or No for restarting Site deamons when down
			restart processes = Yes or No for restarting processes when down
	}
	return
  }
#echo "[exec showroot]"

###########################
#  Get Command Line Args  #
###########################

	set Process [lindex $argv 0]
	set MaxDur [lindex $argv 1]
	set BackupDir [lindex $argv 2]
	set RestartSiteDaemons [lindex $argv 3]
	set RestartProcesses [lindex $argv 4]
echo "\n\nBeginning Cloverleaf_Archive at [clock format [clock seconds]]\n"
echo "Arguments:\n\tSite=$Process\n\tMaxDur=$MaxDur\n\tBackupDir=$BackupDir\n\tRestartSiteDaemons=$RestartSiteDaemons\n\tRestartProcesses=$RestartProcesses"

#######################################
#  Pull site & root from environment  #
#######################################

	set WrkDir [setHciDirs]
	set site $env(HCISITE)
	set rootdir $env(HCIROOT)
echo "HCISITE=$site  HCIROOT=$rootdir"
	set ERRORDIR $rootdir/$site/exec/errors
	#set LOGDIR $rootdir/$site/logs

##########################
#  Get Operating System  #
##########################

	set cerr ""
	if {[catch {set Temp [cequal $env(OS) "Windows_NT"]} cerr]} {
		set NTsystem No
		set TEMPDIR ""
		set TMPDIR /tmp
	} else {
		set NTsystem Yes
		set TEMPDIR $env(TEMP)
		set TMPDIR $env(TMP)
	}

####################################
#  Set process directory variable  #
####################################

	if {[cequal $NTsystem Yes]} {
		set slash [string range $WrkDir 2 2]   ;# Extract correct dir slash (UX vs NT)
	} else {
		set slash [string range $WrkDir 0 0]   ;# Extract correct dir slash (UX vs NT)
	}
	cd $WrkDir

####################################
#  Validate site name (directory)  #
####################################

	set WD [split $WrkDir $slash]

#########################################################
#  Check to see if RestartSiteDaemons variable is set.	#
#  If not set to 0						#
#  Should probably REMOVE					#
#########################################################

	switch -exact  -- [string tolower $RestartSiteDaemons] {
		yes - true - 1 {set RestartSiteDaemons 1}
		no - false - 0 - default {set RestartSiteDaemons 0}
	}
#echo "RestartSiteDaemons=$RestartSiteDaemons"

#####################################################
# Check to see if RestartProcesses variable is set  #
# If not set to 0					   #
# Should probably REMOVE				   #
#####################################################

	switch -exact  [string tolower $RestartProcesses] {
		yes - true - 1 {set RestartProcesses 1}
		no - false - 0 - default {set RestartProcesses 0}
	}
#echo "RestartSiteDaemons=$RestartSiteDaemons"

#########################################################################################################
# Check to make sure the third value in the site directory is the same as the site variable passed in   #
# ex. /hci/root3.7.1P/testsite										      #
# testsite is the third component of the current working directory					      #
#########################################################################################################

	cd $WrkDir
	set whichComponent 4

	if {[lindex $WD $whichComponent] != $site} {
echo "'$site' site name not found!"
		return
	}

###########################################
# Get SiteDaemons				#
# REMOVE if we remove RestartSiteDaemons	#
###########################################

	if {[cequal $NTsystem Yes]} {
		set SiteDaemons [exec $rootdir\\bin\\perl $rootdir\\bin\\hcisitectl.pl]
	} else {
		set SiteDaemons [exec hcisitectl]
	}
#echo "Site Daemons=$SiteDaemons"

#########################################################################################
# If RestartSiteDaemons is selected, check to see if SiteDaemons need to be restarted   #
#########################################################################################

	set NeedToBounce 0
	if {[set RestartSiteDaemons]} {
		set SiteList [split $SiteDaemons \n]
		foreach SiteDaemon $SiteList {
			if {[cequal $SiteDaemon ""]} {continue}
			set DaemonName [lindex $SiteDaemon 0]
			set DaemonStatus [lindex $SiteDaemon 2]
#echo "Site Daemon:  [format "%-25s" $DaemonName]\tStatus: $DaemonStatus"
			if {[cequal $DaemonStatus "NOT"]} {
				set NeedToBounce 1
			}
		}

################################################
# Bounce SiteDaemons if necessary		     #
# Will remove the pid and cmd_port files also  #
################################################

		if {[set NeedToBounce]} {
#echo "site daemons will be bounced"
			if {[cequal $NTsystem Yes]} {
				file delete -force $rootdir\\$site\\exec\\hcimonitord\\pid
				file delete -force $rootdir\\$site\\exec\\hcimonitord\\cmd_port
				exec $rootdir\\bin\\perl $rootdir\\bin\\hcisitectl.pl -K -S
			} else {
				file delete -force $rootdir/$site/exec/hcimonitord/pid
				file delete -force $rootdir/$site/exec/hcimonitord/cmd_port
				exec hcisitectl -K -S
			}
		}
	};# End RestartSiteDeamons 'if'
	set SiteProcesses ""
	set ProcessNotRunning 0
	set cerr ""

#####################################################################################################
# Get list of processes by doing a hciprocstatus command						  #
# If unable to run the hciprocstatus command output error and pull list of processes from NetConfig #
#####################################################################################################

	if {[cequal $NTsystem Yes]} {
		if {[catch {set SiteProcess [exec $rootdir\\bin\\hcitcl $rootdir\\bin\\hciprocstatus.htc]} cerr]} {
echo "warning: $cerr"
			set ProcessNotRunning 1
			set NetFile $rootdir\\$site\\NetConfig
echo "getting thread names from NetConfig file=$NetFile"
			set SiteProcess [exec $env(windir)/system32/findstr process $NetFile]
			regsub -all -nocase -- process $SiteProcess "" SiteProcess
			regsub -all -- {\{} $SiteProcess "" SiteProcess
			set SiteProcess [join [split $SiteProcess \n]]
		} else {
			regsub -all -- "    " $SiteProcess " " SiteProcess
			regsub -all -- "   " $SiteProcess " " SiteProcess
			regsub -all -- "  " $SiteProcess " " SiteProcess
			set SiteProcess [join [lreplace [split $SiteProcess \n] 0 1 ] \n]
#echo "SiteProcess=$SiteProcess"
		}
	} else {
		if {[catch {set SiteProcess [exec hciprocstatus]} cerr]} {
#echo "cerr=$cerr"
#echo "Warning: cannot contact processes names via procstatus"
			set ProcessNotRunning 1
			set NetFile $rootdir/$site/NetConfig
echo "getting thread names from NetConfig file=$NetFile"
			set SiteProcess [exec /bin/grep process $NetFile]
			regsub -all -nocase -- process $SiteProcess "" SiteProcess
			regsub -all -- {\{} $SiteProcess "" SiteProcess
		} else {
			# Customization since Centra has long process names
			set NetFile $rootdir/$site/NetConfig
echo "getting thread names from NetConfig file=$NetFile"
			set SiteProcess [exec /bin/grep "^process" $NetFile]
			regsub -all -- {\{} $SiteProcess "" SiteProcess
			# End of Customization
			regsub -all -- "    " $SiteProcess " " SiteProcess
			regsub -all -- "   " $SiteProcess " " SiteProcess
			regsub -all -- "  " $SiteProcess " " SiteProcess
			#set SiteProcess [join [lreplace [split $SiteProcess \n] 0 1 ] \n]
		}
	}
	set SiteProcList [split $SiteProcess \n]
echo "SiteProcList=$SiteProcList"

###########################################################
# Begin foreach loop for each process in the process list #
###########################################################

	foreach SiteProcess $SiteProcList {
		# Begin Customization for process name size
		set Process [lindex $SiteProcess 1]
		set SiteProcess [exec hciprocstatus -p $Process]
		regsub -all -- "    " $SiteProcess " " SiteProcess
		regsub -all -- "   " $SiteProcess " " SiteProcess
		regsub -all -- "  " $SiteProcess " " SiteProcess
		set SiteProcess [join [lreplace [split $SiteProcess \n] 0 1] \n]
		# End of Customization
		set SiteProcess [string trimleft $SiteProcess]
		if {[cequal $SiteProcess ""]} {continue}
		set SiteProcess [split $SiteProcess]
		# next line removed for process name size issue
		#set Process [lindex $SiteProcess 0]
echo "SiteProcess=$SiteProcess"
		#################################################
		# Check to see if process is currently running  #
		#################################################
		set ProcessStatus [lindex $SiteProcess 1]
		if {[cequal $ProcessStatus ""]} {
			set ProcessStatus "not available"
		} else {
			set ProcessStatus [lindex $SiteProcess 1]
		}
echo "Site Process: [format "%-25s" $Process]\tStatus: $ProcessStatus"
		########################################################################
		# If process is dead check to see if RestartProcesses variable is set  #
		########################################################################
		if {[cequal $ProcessStatus "dead"]} {
			set ProcessNotRunning 1
			if {[set RestartProcesses]} {
echo "site process will be bounced"
				set cerr ""
				################################################################
				# Restart Processes							#
				# If hcienginestop command fails remove cmd_port and pid files	#
				# REMOVE if we remove RestartProcesses variable			#
				################################################################
				if {[cequal $NTsystem Yes]} {
					if {[catch {exec $rootdir\\bin\\perl $rootdir\\bin\\hcienginestop.pl -p $Process} cerr]} {
#echo "cerr=$cerr"
					}
					file delete -force $rootdir/$site/exec/processes/$Process/pid
					file delete -force $rootdir/$site/exec/processes/$Process/wpid
					file delete -force $rootdir/$site/exec/processes/$Process/cmd_port
					if {[catch {exec $rootdir\\bin\\perl $rootdir\\bin\\hcienginerun.pl -p $Process} cerr]} {
#echo "cerr=$cerr"
					} else {
						set ProcessNotRunning 0
					}
				} else {
					if {[catch {exec hcienginestop -p $Process} cerr]} {
#echo "cerr=$cerr"
					}
					file delete -force $rootdir/$site/exec/processes/$Process/pid
					file delete -force $rootdir/$site/exec/processes/$Process/wpid
					file delete -force $rootdir/$site/exec/processes/$Process/cmd_port
					if {[catch {exec hcienginerun -p $Process} cerr]} {
#echo "cerr=$cerr"
					} else {
						set ProcessNotRunning 0
					}
				}
			}
		}

###############################################################
# Set backup directory to /hci/savefiles if BackupDir not set #
###############################################################

	cd $WrkDir
	if {[cequal $NTsystem Yes]} {
		if {[cequal $BackupDir ""]} {
			set BackupDir "c:\\$rootdir\\savefiles"
		}
	} else {
		if {[cequal $BackupDir ""]} {
			set BackupDir "/$rootdir/Archive"
		}
	}

##################################################################
# Validate site name (directory).  Exit & report if not found #
##################################################################

	if {[file exist $Process] == 0} {
echo "'$Process' site directory not found in $WrkDir"
		return
	}

# Site directory exists, so move to it
	cd $Process
################################################
# Create Today's sub-directory for saved files #
################################################

	if {[cequal $NTsystem Yes]} {
		set Now_Dir "$BackupDir\\$site\\[clock format [clock seconds] -format {%m_%b_%d}]\\$Process"
	} else {
		set Now_Dir "$BackupDir/$site/[clock format [clock seconds] -format {%m_%b_%d}]/$Process"
	}
	if {[file exist $Now_Dir] == 1} {	;# If current does not directory exists, create it
	} else {
		file mkdir $Now_Dir		;# Create today's sub_directory
	}
echo "Process Archive: $Now_Dir"
####################################################
# Get list of threads with the hciconndump command #
####################################################

	if {[cequal $NTsystem Yes]} {
		set threads [exec $rootdir\\bin\\hcitcl $rootdir\\bin\\hciconndump.htc -p $Process]
	} else {
		set threads [exec hciconndump -p $Process]
	}
	set threads [split $threads \n]		;# Break into list on line feeds
	set thrknt [llength $threads]		;# Get number of lines


#####################################################
# Create "Nthread" list (contains all thread names) #
#####################################################

	set Nthread ""
	while {$thrknt >= 4} {					;# Use 4 to keep from getting header
		set thrname [lindex $threads [expr $thrknt - 1]]	;# "-1" used because list index starts at 0
		set thrname [string range $thrname 16 48]		;# Pick out thread name
		set thrname [string trimright $thrname]		;# Remove blank spaces
		lappend Nthread $thrname				;# Concantenate clean thread names into a list
		incr thrknt -1
	};# end of while

########################################################################
# Cycle (all possible) save files using the hcicmd, save_cycle feature #
########################################################################

	set knt [expr [llength $Nthread] -1]
	while {$knt >= 0} {
		if {![set ProcessNotRunning]} {
			if {[cequal $NTsystem Yes]} {
#echo "Thread=[lindex $Nthread $knt]"
				set loopmax 30000
				for {set s1 0} {$s1 < $loopmax} {incr s1}  {
					set cerr ""
					if {! [expr $s1 % 100]} {
#echo "100 seconds"
						####################
						# Do save_cycle in #
						####################
						if {[catch {exec $rootdir/bin/hcicmdnt -p $Process -c "[lindex $Nthread $knt] save_cycle in"} cerr]} {  
							if {[cequal $cerr "saving of inbound messages is not active"]} {
#echo "cerr=$cerr"
								set s1 $loopmax
								break;
							}
#echo "cerr=$cerr"
						} else {
#echo "Finally"
							set s1 $loopmax
							break;
						}
					}
				};# End for
				#####################
				# Do save_cycle out #
				#####################
				if {[catch {exec $rootdir/bin/hcicmdnt -p $Process -c "[lindex $Nthread $knt] save_cycle out"} cerr]} {
#echo "cerr=$cerr"
				}
			} else {
echo "   cycling ib smat for Thread...[lindex $Nthread $knt]"
#echo "Thread=[lindex $Nthread $knt]"

				set cerr ""
				####################
				# Do save_cycle in #
				####################
				if {[catch {exec $rootdir/bin/hcicmd -p $Process -c "[lindex $Nthread $knt] save_cycle in"} cerr]} { 
echo "Cycle save in error=$cerr"
				}
echo "   cycling ob smat for Thread...[lindex $Nthread $knt]"

				#####################
				# Do save_cycle out #
				#####################
				if {[catch {exec $rootdir/bin/hcicmd -p $Process -c "[lindex $Nthread $knt] save_cycle out"} cerr]} { 
echo "Cycle save out error=$cerr"
				}
			} ;#end of if
		}
		#########################
		# Get Thread statistics #
		#########################
		if {[catch {exec $rootdir/bin/hcimsiutil -dd [lindex $Nthread $knt] >> $Now_Dir/statistics} cerr]} { ;#	Get the thread statistics
#echo "cerr=$cerr"
		}
		incr knt -1
	};#	end of while
######################
# Cycle output files #
######################
	set cerr ""
	if {![set ProcessNotRunning]} {
		if {[cequal $NTsystem Yes]} {
			set cerr ""
			if {[catch {exec $rootdir/bin/hcicmdnt -p $Process -c ". output_cycle in"} cerr]} {
#echo "cerr=$cerr"
			} else {
#echo "Logs cycled"
			}
		} else {
			if {[catch {exec $rootdir/bin/hcicmd -p $Process -c ". output_cycle in"} cerr]} {
#echo "cerr=$cerr"
			} else {
echo "Log Files cycled"
			}
		}
	} ;#end of if
####################################
# Create the LogHistory files list #
####################################
	set LogFiles ""
	set ix_start ""
	set ix_end ""
	set log_hist_dest $rootdir/$site/exec/processes/$Process/LogHistory
	if {[file exist $log_hist_dest] == 1} {	;# If current does not directory exists, create it
	} else {
		file mkdir $log_hist_dest		;# Create today's sub_directory
	} 
	cd $rootdir/$site/exec/processes/$Process/LogHistory
	set LogFiles  [glob -nocomplain *.log *.err]
	if {[cequal $LogFiles ""]} {
echo "No LogHistory to archive"
	} else {
#echo "LogHistory currently contains: =$LogFiles"
		foreach file $LogFiles {
			#######################################################################
			# Parse log files to get date in order to copy to proper subdirectory #
			#######################################################################
			set log_file_archive ""
			set ix_start [string wordend $Process 0]
			set ix_end [expr $ix_start +3]
			set log_date [string range $file $ix_start $ix_end]
#echo "Log date for $file is: $log_date"
			set log_month_num [string range $log_date 0 1]
			set log_month [string range $log_date 0 1]
			set log_day [string range $log_date 2 3]
			switch -exact -- $log_month {
				01 {set log_month "Jan"}
				02 {set log_month "Feb"}
				03 {set log_month "Mar"}
				04 {set log_month "Apr"}
				05 {set log_month "May"}
				06 {set log_month "Jun"}
				07 {set log_month "Jul"}
				08 {set log_month "Aug"}
				09 {set log_month "Sep"}
				10 {set log_month "Oct"}
				11 {set log_month "Nov"}
				12 {set log_month "Dec"}
			}
			#append log_file_archive $log_month_num "_" $log_month "_" $log_day
#echo "Log file archive is: $log_file_archive"
			#set log_file_dest "$BackupDir/$site/$log_file_archive/$Process"
			# Check for existence of directory and create it if not found
			#if {[file exist $log_file_dest] == 1} {	;# If current does not directory exists, create it
			#} else {
				#file mkdir $log_file_dest	;# Create today's sub_directory
			#} 
#echo "Log file to copy: $file"
			file copy -force $file $Now_Dir
			file delete $file
#echo "Log file $file copied to: $Now_Dir "
		}
	};# End if
#####################################
# Create the SmatHistory files list #
#####################################
	set SmatFiles ""
	set smat_hist_dest $rootdir/$site/exec/processes/$Process/SmatHistory
echo "SMAT History location is: $smat_hist_dest"
	if {[file exist $smat_hist_dest] == 1} {	;# If current does not directory exists, create it
	} else {
		file mkdir $smat_hist_dest		;# Create today's sub_directory
	} 
	cd $rootdir/$site/exec/processes/$Process/SmatHistory
	set SmatFiles  [glob -nocomplain *.ecd *.smatdb]
	if {[cequal $SmatFiles ""]} {
echo "No SmatHistory to archive"
	} else {
#echo "SmatHistory currently contains: =$SmatFiles"
		foreach file $SmatFiles {
			########################################################################
			# Parse Smat files to get date in order to copy to proper subdirectory #
			########################################################################
			set smat_file_archive ""
			set smat_date [string range [lindex [split $file "."] 1] 4 7]
#echo "Smat date for $file is: $smat_date"
			set smat_month_num [string range $smat_date 0 1]
			set smat_month [string range $smat_date 0 1]
			set smat_day [string range $smat_date 2 3]
			switch -exact -- $smat_month {
				01 {set smat_month "Jan"}
				02 {set smat_month "Feb"}
				03 {set smat_month "Mar"}
				04 {set smat_month "Apr"}
				05 {set smat_month "May"}
				06 {set smat_month "Jun"}
				07 {set smat_month "Jul"}
				08 {set smat_month "Aug"}
				09 {set smat_month "Sep"}
				10 {set smat_month "Oct"}
				11 {set smat_month "Nov"}
				12 {set smat_month "Dec"}
			}
			#append smat_file_archive $smat_month_num "_" $smat_month "_" $smat_day
			#set smat_file_dest "$BackupDir/$site/$smat_file_archive/$Process" 
#echo $smat_file_dest
			# Check for existence of directory and create it if not found
			#if {[file exist $smat_file_dest] == 1} {	;# If current does not directory exists, create it
			#} else {
				#file mkdir $smat_file_dest		;# Create today's sub_directory
			#}
#echo "Smat file to copy: $file"
			file copy -force $file $Now_Dir
			file delete $file
echo "Smat file $file copied to: $Now_Dir"
		}
	} ;# end of if

####################################################
# Delete site sub-directories past retention date  #
####################################################
	cd $BackupDir/$site
	if {[cequal $NTsystem Yes]} {
		set Dirs "[exec cmd /c dir ???_?? | findstr DIR]"
		set DirsList [split $Dirs \n]
	} else {
		set Dirs [glob -nocomplain ??_???_??]
		set DirsList [split $Dirs]
	}
#echo "DirsList=$DirsList"
	if {[expr $MaxDur < 0]} {
		set MaxDur [expr $MaxDur * -1]
		set OldDate [clock scan  "today +$MaxDur days"]
	} else {
		set OldDate [clock scan  "today -$MaxDur days"]
	}
	foreach Dir $DirsList {
#echo "Dir=$Dir"
		if {[cequal $NTsystem Yes]} {
			set DirDate [lindex $Dir 0]
			set FileName [lindex $Dir 3]
			set DateToCheck [clock scan $DirDate]
		} else {
			file stat $Dir DirInfo
			set DateToCheck [set DirInfo(mtime)]
			set FileType [set DirInfo(mtime)]
			set FileName $Dir
		}
			set TodaysDate [clock format [clock seconds]]
			set Diff [expr $OldDate - $DateToCheck]
			if {$Diff > 0} {
echo "$BackupDir/$site/$FileName deleted"
				file delete -force $BackupDir/$site/$FileName
			}
	} ;# end of foreach loop
	set ProcessNotRunning 0
	} ;# end of Process loop

###############################################################################
# Clear out statistics for threads in the process (whether it is up or down)  #
###############################################################################

echo "Zero out statistics for all threads in the process"
	if {[cequal $NTsystem Yes]} {
		if {[catch {exec $rootdir/bin/hcimsiutil -X > $TMPDIR\\archive.tmp} cerr] } { ;#   Get the thread statistic
#echo "cerr=$cerr"
	}
	} else {
		if {[catch {exec $rootdir/bin/hcimsiutil -X > $env(DEV_NULL)} cerr]} { ;# Get the thread statistics
#echo "cerr=$cerr"
		}
	} ;#end of if

########################
# Other site cleanups  #
########################

	foreach SiteDirToClear {ERRORDIR TMPDIR TEMPDIR} {
		if {[cequal [set $SiteDirToClear] ""]} {continue}
		set SiteDirToClear [set $SiteDirToClear]
		if {[catch {cd $SiteDirToClear} cerr]} {
echo "Cannot cd to $SiteDirToClear"
		} else {
			set FileList [glob -nocomplain *]
echo "Removing old files in $SiteDirToClear"
			if {![cequal $FileList ""]} {
				if {[expr $MaxDur < 0]} {
					set MaxDur [expr $MaxDur * -1]
					set OldDate [clock scan  "today +$MaxDur days"]
				} else {
					set OldDate [clock scan  "today -$MaxDur days"]
				}
				foreach File $FileList {
					if {[catch {[file stat $File FileInfo]} cerr]} {
						set DateToCheck [set FileInfo(atime)]
						set FileType [set FileInfo(atime)]
						set FileName $File
						set TodaysDate [clock format [clock seconds]]
						set Diff [expr $OldDate - $DateToCheck]
						if {$Diff > 0} {
							if {[catch {[file delete -force $SiteDirToClear/$FileName]} cerr]} {
echo "$SiteDirToClear/$FileName could not be removed"
							} else {
echo "$SiteDirToClear/$FileName deleted"
							}
						} ;#End of Diff if
					} else {
echo "Not a valid filename: $SiteDirToClear/$FileName"
					}	;# end of catch file stat if
				}		;# end of foreach FileList loop
			}			;# end of FileList if
		}				;# end of catch SiteDirToClear if
	}					;# end of foreach loop
echo "\n\Ending Cloverleaf_Archive at [clock format [clock seconds]]\n"

