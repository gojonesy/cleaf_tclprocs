#!/usr/bin/env tcl
# Sends an email with $body of $content_type and $subject to $to
# 02/20/2018 - Jones - Created

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
