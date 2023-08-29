PARAMETER notUseExtension IS FALSE, //set if the file being updated must have the same extension as the file on the archive to be updated (FALSE = use and TRUE = ignore)
notUsePath IS TRUE, //sets if the file being updated must have the same path ignoreing voulme to be updated (FALSE = use and TRUE = ignore)
notUseSize IS TRUE. //sets if the file being updated must have a different size compared to the file on the archive to be updated (FALSE = use and TRUE = ignore)
IF EXISTS("0:/") {
RUNONCEPATH("1:/lib/lib_file_util.ks").
CLEARSCREEN.
LOCAL localDir IS LIST().
LIST VOLUMES IN localDir.
LOCAL archiveDir IS localDir[0].
localDir:REMOVE(0).
LOCAL extList IS LIST("ks").

LOCAL localFiles IS dir_list_scan(localDir,extList).
LOCAL archiveFiles IS dir_scan(archiveDir,extList).

CD("1:/").
FOR lFile IN localFiles {
	FOR aFile IN archiveFiles {
		IF name_only(aFile[1]) = name_only(lFile[1]) {//name check
			IF no_root(aFile[0]) = no_root(lFile[0]) OR notUsePath {//path check
				IF  aFile[1]:SIZE <> lFile[1]:SIZE OR notUseSize {//size check
					IF aFile[1]:EXTENSION = lFile[1]:EXTENSION OR notUseExtension {//extension check
						COPYPATH(aFile[0]:COMBINE(aFile[1]:NAME),lFile[0]).
						PRINT "Copying File: " + aFile[1].
						PRINT "        From: " + aFile[0] + " To: " + lFile[0].
						PRINT " ".
					}
				}
			}
		}
	}
}} ELSE { PRINT "Archive Not Found". }