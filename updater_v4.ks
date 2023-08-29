PARAMETER notUseExtension IS FALSE, //set if the file being updated must have the same extension as the file on the archive to be updated (FALSE = use and TRUE = ignore)
notUsePath IS FALSE, //sets if the file being updated must have the same path ignoring volume to be updated (FALSE = use and TRUE = ignore)
notUseSize IS TRUE, //sets if the file being updated must have a different size compared to the file on the archive to be updated (FALSE = use and TRUE = ignore)
useCompile IS TRUE.//sets if the updater will compile .ks files on archive to .ksm on local if all other conditions match (FALSE = don't compile and TRUE = compile)
IF EXISTS("0:/") {
FOR lib IN LIST("lib_file_util") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
CLEARSCREEN.
LOCAL localDir IS LIST().
LIST VOLUMES IN localDir.
LOCAL archiveDir IS localDir[0].
localDir:REMOVE(0).
LOCAL extList IS LIST("ks","ksm").

LOCAL localFiles IS dir_scan(localDir,extList).
LOCAL archiveFiles IS dir_scan(archiveDir,extList).

FOR lFile IN localFiles {
	FOR aFile IN archiveFiles {
		IF name_only(aFile[1]) = name_only(lFile[1]) {//name check
			IF notUsePath OR (no_root(aFile[0]) = no_root(lFile[0])) {//path check
				IF notUseSize OR (aFile[1]:SIZE <> lFile[1]:SIZE) {//size check
					IF notUseExtension OR (aFile[1]:EXTENSION = lFile[1]:EXTENSION) {//extension check
						COPYPATH(aFile[0]:COMBINE(aFile[1]:NAME),lFile[0]).
						PRINT "Copying File: " + aFile[1].
						PRINT "        From: " + aFile[0] + " To: " + lFile[0].
						PRINT " ".
					}
				}
				IF useCompile AND (aFile[1]:EXTENSION = "ks") AND (lFile[1]:EXTENSION = "ksm") {
					PRINT "Compiling File: " + aFile[1].
					PRINT "          From: " + aFile[0] + " To: " + lFile[0].
					COMPILE aFile[0]:COMBINE(aFile[1]:NAME) TO lFile[0]:COMBINE(name_only(lFile[1]) + ".ksm").
					PRINT "Done Compiling: " + aFile[1].
					PRINT " ".
				}
			}
		}
	}
}} ELSE { PRINT "Archive Not Found". }