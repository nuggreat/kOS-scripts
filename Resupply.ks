LOCAL defaultTags IS LEXICON("in"," ","out"," ").
IF EXISTS("1:/data/resuply_default.json") {
	LOCAL defaultData IS READJSON("1:/data/resuply_default.json").
	SET defaultTags TO defaultData.
}

PARAMETER pumpOutTags IS defaultTags["out"],pumpInTags IS defaultTags["in"],setDefault IS FALSE.

IF setDefault {
	IF NOT EXISTS("1:/data/") {CREATEDIR("1:/data/").}
	WRITEJSON(LEXICON("in",pumpInTags,"out",pumpOutTags),"1:/data/resuply_default.json").
	PRINT "defaults set".
} ELSE {
	RUN fuel_pump(pumpOutTags,"out").
	RUN fuel_pump(pumpInTags,"in").
}
