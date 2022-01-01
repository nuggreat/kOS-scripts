FUCNTION init_obj {
	PARAMETER a, b, c.
	LOCAL objLex IS LEX().
	objLex:ADD("abSUM",{ RETURN a + b. }).
	objLex:ADD("acSUM",{ RETURN a + c. }).
	objLex:ADD("bcSUM",{ RETURN b + c. }).
	objLex:ADD("abcSUM",{ RETURN a + b + c. }).
	objLex:ADD("SETa"{ PARAMETER newA. SET a TO newA. }).
	objLex:ADD("SETb"{ PARAMETER newB. SET b TO newB. }).
	objLex:ADD("SETc"{ PARAMETER newC. SET b TO newC. }).
	RETURN objLex.
}