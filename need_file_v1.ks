PARAMETER neededFile.	//-----parameter must have filename.extenstion in a singel string-----
RUNONCEPATH("1:/lib/lib_file_util.ks").

LOCAL archiveDir IS LIST("0:/").
LOCAL localDir IS LIST("1:/").
LOCAL extList IS LIST(-99999).
LOCAL localFiles IS LIST().
LOCAL archiveFiles IS LIST().

FOR lDir IN localDir { scan(lDir,localFiles,extList). }
FOR aDir IN archiveDir { scan(aDir,archiveFiles,extList). }
CD("1:/").
LOCAL copyNeeded IS TRUE.
FOR lFile IN localFiles {
	SET copyNeeded TO copyNeeded OR (NOT lFile[1]:NAME = neededFile).
}
IF copyNeeded {
	FOR aFile IN archiveFiles {
		IF aFile[1]:NAME = neededFile{
			LOCAL localPath IS PATH(localDir):ROOT:COMBINE(no_root(aFile[0]:SEGMENTS,0)).
			PRINT localPath.
			IF NOT EXISTS(localPath) {
				PRINT " Making  dir: " + localPath.
				CREATEDIR(localPath).
			}
			COPYPATH(aFile[0]:COMBINE(aFile[1]:NAME),localPath).
			PRINT "Copying File: " + aFile[1].
			PRINT "        From: " + aFile[0] + " To: " + localPath.
			PRINT " ".
		}
	}
}

FUNCTION no_root {
	PARAMETER seg,
	count.
	IF seg:LENGTH = 0 { RETURN "". }
	IF count + 1 = seg:LENGTH { RETURN seg[count]. }
	RETURN seg[count]:COMBINE(no_root(seg,count + 1)).
}