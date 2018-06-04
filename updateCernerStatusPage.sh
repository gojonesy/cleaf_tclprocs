#!/usr/bin/env bash

/hci/cis6.1/integrator/contrib/getMilliDomains.tcl > /hci/cis6.1/integrator/contrib/cernerStatus.html

scp -pr /hci/cis6.1/integrator/contrib/cernerStatus.html hci@clvrlf-gm-ss-mmp01:/hci/cloverleaf/gm6.1/webapps/ROOT/ifc/cernerStatus.html
