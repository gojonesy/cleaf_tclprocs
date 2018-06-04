######################################################################
# Name:		tps_send_mail
# Purpose:	<description>
# UPoC type:	tps
# Args: 	tps keyedlist containing the following keys:
#       	MODE    run mode ("start", "run" or "time")
#       	MSGID   message handle
#       	ARGS    user-supplied arguments:
#               	<describe user-supplied args here>
#
# Returns: tps disposition list:
#          <describe dispositions used here>
#

proc tps_send_mail { args } {
    keylget args MODE mode              	;# Fetch mode

    set dispList {}				;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
	    # N.B.: there may or may not be a MSGID key in args
	    # 	echo calling smtp_mail_test
	    # 	smtp_mail_send "this message is in the attachment\n" "this message is in the body\n"
        }

        run {
	    # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
	    set userdata [msgmetaget $mh USERDATA]
	    set content_type [keylget userdata CONTENT_TYPE]
	    set subject [keylget userdata SUBJECT]
	    set to [join [keylget userdata TO] ,]
	    smtp_mail_send [msgget $mh] $content_type $subject $to
            lappend dispList "CONTINUE $mh"
        }

        time {
            # Timer-based processing
	    # N.B.: there may or may not be a MSGID key in args
        }
        
        shutdown {
	    # Doing some clean-up work 
	}
    }

    return $dispList
}

proc smtp_mail_send { body content_type subject to } {
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
	-servers { 10.40.35.26 } \
	-header [list From "hciuser@valleymed.org"] \
	-debug 1 -usetls 0
}
