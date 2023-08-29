FUNCTION init_obj {
	PARAMETER a, b.
	LOCAL objLex IS LEX().
	objLex:ADD("SUMab", {
		RETURN a + b.
	}).
	objLex:ADD("GETa", {
		RETURN a.
	}).
	objLex:ADD("GETb", {
		RETURN b.
	}).
	objLex:ADD("SETa",{
		PARAMETER newA.
		SET a TO newA.
	}).
	objLex:ADD("SETb",{
		PARAMETER newB.
		SET b TO newB.
	}).
	RETURN objLex.
}

LOCAL obj0 IS init_obj(1,2).
PRINT obj0:SUMab().//will print 3
PRINT obj0:GETa().//will print 1
obj0:SETa(5).
PRINT obj0:GETa().//will print 5