#!/hci/qdx5.7/integrator/bin/tcl

# Using the SMAT .idx file, convert a SMAT .msg file into a newline format, ignore metadata
# .msg: metadata == OFFSET of current record - LENGTH of previous record
#
# Old style
#        {OFFSET 0}
#        {LENGTH 16476723}
#
# New style
# .idx: {OFFSET 0                   } {LENGTH 2666      }

set fileName [string map {.idx "" .msg "" .ecd ""} [lindex $argv 0]]
if {![file exists $fileName.idx]} {puts stderr "The $fileName.idx file does not exist"; return 0;}
set f [open $fileName.idx r]; fconfigure $f -translation binary; set records [read $f]; close $f

set OFFSET [regexp -inline -all {{OFFSET (.*?)}} $records]
set LENGTH [regexp -inline -all {{LENGTH (.*?)}} $records]

set f [open $fileName.msg r]; fconfigure $f -translation binary;

foreach offset $OFFSET length $LENGTH {
    if {[regexp {\{} $offset]} {continue} ;# Skip regexp matches & keep captures
    seek $f $offset start
    puts [read $f $length]
}

close $f