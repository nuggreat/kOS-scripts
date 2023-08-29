IF EXISTS("0:/") {
RUNONCEPATH("1:/lib/lib_file_util.ks").
CLEARSCREEN.
LOCAL localDir IS LIST().
LIST VOLUMES IN localDir.
LOCAL archiveDir IS localDir[0].
localDir:REMOVE(0).
LOCAL extList IS LIST("ks").

LOCAL localFiles IS dir_scan(localDir,extList).
LOCAL archiveFiles IS dir_scan(archiveDir,extList).

FOR lFile IN localFiles { FOR aFile IN archiveFiles {
	IF name_only(aFile[1]) = name_only(lFile[1]) { IF aFile[1]:EXTENSION = lFile[1]:EXTENSION {
		COPYPATH(aFile[0]:COMBINE(aFile[1]:NAME),lFile[0]).
		PRINT "Copying File: " + aFile[1].
		PRINT "        From: " + aFile[0] + " To: " + lFile[0].
		PRINT " ".
	}}
}}} ELSE { PRINT "Archive Not Found". }