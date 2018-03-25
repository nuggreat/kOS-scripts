IF NOT EXISTS("1:/lib/lib_file_util.ks") {
	COPYPATH("0:/lib/lib_file_util.ks","1:/lib/").
}
RUNONCEPATH("1:/lib/lib_file_util.ks").
CLEARSCREEN.
LOCAL localDir IS LIST().
LIST VOLUMES IN localDir.
LOCAL archiveDir IS LIST(localDir[0]).
localDir:REMOVE(0).
LOCAL extList IS LIST("ks").
LOCAL localFiles IS LIST().
LOCAL archiveFiles IS LIST().

FOR aDir IN archiveDir {
	scan(aDir,archiveFiles,extList).
}
FOR lDir IN localDir {
	scan(lDir,localFiles,extList).
}
CD("1:/").
FOR lFile IN localFiles {
	FOR aFile IN archiveFiles {
		IF (aFile[1]:NAME = lFile[1]:NAME) AND (aFile[1]:EXTENSION = lFile[1]:EXTENSION) {
			COPYPATH(aFile[0]:COMBINE(aFile[1]:NAME),lFile[0]).
			PRINT "Copying File: " + aFile[1].
			PRINT "        From: " + aFile[0] + " To: " + lFile[0].
			PRINT " ".
		}
	}
}