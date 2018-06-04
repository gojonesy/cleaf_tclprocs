#!/usr/bin/env bash

# Uploads all of the cloverleaf documentation files to the GM server. Files should be setup in $HCIROOT/contrib/html/
scp -pr /hci/cis6.1/integrator/contrib/html/cernerStatus.html hci@clvrlf-gm-ss-mmp01:/hci/cloverleaf/gm6.1/webapps/ROOT/ifc/
scp -pr /hci/cis6.1/integrator/contrib/html/clDocsBase.html hci@clvrlf-gm-ss-mmp01:/hci/cloverleaf/gm6.1/webapps/ROOT/ifc/
scp -pr /hci/cis6.1/integrator/contrib/html/*.html hci@clvrlf-gm-ss-mmp01:/hci/cloverleaf/gm6.1/webapps/ROOT/ifc/test/

