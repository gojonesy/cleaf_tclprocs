#!/usr/bin/env tcl
# Makes example TW Unity Calls via curl
# 06/25/2018 - Jones - Created

set headers "{Content-Type: application/json}"
# this is the productyion unity url
# set baseUrl "https://touchworks.ehrspi.com/Unity/UnityService.svc"

# This is the unitysandbox url.
set baseUrl "http://twlatestga.unitysandbox.com/Unity/UnityService.svc"

set appName "MemorialMedicalCenter.PHEnOM.TestApp"
set svcUserName "Memor-6aa2-PHEnOM-test"
set svcPassword "M%7!rf@cm0d7C@8C%nT4rPh6N!fT%s"
set Ehr_username "jmedici"
set Ehr_password  "password01"

# First, prior to any call, you have to call and get a token:
set dataString "\{\"Username\":\"$svcUserName\", \"Password\":\"$svcPassword\"\}"
set patientString ""
puts "Headers: $headers"
puts "DataString: $dataString"
## The Unity API is exceptionally picky about the content in the api call.
## These curl calls need to be made exactly as they're written here with tcl.
# The correct curl call to get a token:
# curl --request POST --url http://twlatestga.unitysandbox.com/Unity/UnityService.svc/json/GetToken --header 'Content-Type: application/json' --data '{"Username":"Memor-6aa2-PHEnOM-test", "Password":"M%7!rf@cm0d7C@8C%nT4rPh6N!fT%s"}'

catch {exec curl --request POST --url $baseUrl/json/GetToken --header {Content-Type: application/json} --data $dataString} returnVal
puts "returnVal: $returnVal"
set token [lindex $returnVal 0]
puts "Token: $token"


## We are prepared to make other calls now. the GetPatient call follows:

# The correct curl call to get a Patient:
#curl --request POST --url http://twlatestga.unitysandbox.com/Unity/UnityService.svc/json/MagicJson --header 'Content-Type: application/json' --data '{"Action":"GetPatient", "Appname":"MemorialMedicalCenter.PHEnOM.TestApp", "AppUserID":"jmedici", "PatientID":"22", "Token":"55A7584D-981C-4A42-8E88-CB99CFFCC6C7", "Parameter1":"", "Parameter2":"", "Parameter3":"", "Parameter4":"", "Parameter5":"", "Parameter6":"", "Data":""}'
catch {exec curl --request POST --url $baseUrl/json/MagicJson --header {Content-Type: application/json} --data "{\"Action\":\"GetPatient\", \"Appname\":\"MemorialMedicalCenter.PHEnOM.TestApp\", \"AppUserID\":\"jmedici\", \"PatientID\":\"22\", \"Token\":\"$token\", \"Parameter1\":\"\", \"Parameter2\":\"\", \"Parameter3\":\"\", \"Parameter4\":\"\", \"Parameter5\":\"\", \"Parameter6\":\"\", \"Data\":\"\"}"} getPatientReturnVal
puts "Raw return val: $getPatientReturnVal"
puts "getPatientReturnVal: [lindex [split $getPatientReturnVal "%"] 0]"
