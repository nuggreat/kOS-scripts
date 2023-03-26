IF NOT EXISTS("0:/min_test/") {CREATEDIR("0:/min_test/").}
// IF NOT EXISTS("1:/lib/") {CREATEDIR("1:/lib/").}

// FOR f IN OPEN("1:/min_test/"):LEX:VALUES {
	// DELETEPATH("1:/min_test/" + f:NAME).
// }

// PRINT "holding pending RCS".
// RCS OFF.
// WAIT UNTIL RCS.
PRINT "loading lib".
// RUNPATH("0:/lib/lib_minify.ks").
RUNPATH("0:/min_test/lib_minify.ksr").
PRINT "running file".
// minify("0:/lib/lib_minify.ks","0:/min_test/lib_minify.ksr").
// minify("0:/lib/lib_minify.ks","0:/min_test/lib_minify2.ksr").
PRINT "ran file".
PRINT OPEN("0:/min_test/lib_minify2.ksr"):READALL():STRING = OPEN("0:/min_test/lib_minify.ksr"):READALL():STRING.