PARAMETER fileName,	//fileName must be a string of the file name with out the extension EXAMPLE: "need_file"
fileExt IS "". //fileExt must be a string of the file extension with out everything before
IF EXISTS("1:/lib/lib_file_util.ksm") { RUNONCEPATH("1:/lib/lib_file_util.ksm"). } ELSE { RUNONCEPATH("1:/lib/lib_file_util.ks"). }

LOCAL archiveDir IS PATH("0:/").
LOCAL localDir IS PATH("1:/").
LOCAL extList IS LIST(-99999).

PRINT " ".
LOCAL copyNeeded IS TRUE.
FOR localFile IN dir_scan(localDir,extList) {
	IF name_only(localFile[1]) = fileName {
		IF localFile[1]:EXTENSION = fileExt OR fileExt = "" {
			PRINT "Local Copy Found of File: " + fileName.
			PRINT "Local Copy Found at:      " + localFile[0].
			SET copyNeeded TO FALSE.
			WAIT 1.
		}
	}
}

IF copyNeeded {
	PRINT "No Local Copy of File: " + fileName.
	PRINT "Scaning Archive".
	IF EXISTS("0:/") {
		FOR archiveFile IN dir_scan(archiveDir,extList) {
			IF name_only(archiveFile[1]) = fileName {
				IF archiveFile[1]:EXTENSION = fileExt OR fileExt = "" {
					LOCAL localPath IS localDir:ROOT:COMBINE(no_root(archiveFile[0])).
					IF NOT EXISTS(localPath) {
						PRINT " Making  dir: " + localPath.
						CREATEDIR(localPath).
					}
					COPYPATH(archiveFile[0]:COMBINE(archiveFile[1]:NAME),localPath).
					PRINT " ".
					PRINT "Copying File: " + archiveFile[1].
					PRINT "        From: " + archiveFile[0] + " To: " + localPath.
					PRINT " ".
				}
			}
		}
	} ELSE { PRINT "Archive Not Found". }
}