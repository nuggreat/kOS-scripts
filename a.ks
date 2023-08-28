PRINT " ".
LOCAL runMult IS 1.
LOCAL totalCalls IS FLOOR(runMult) * CONFIG:IPU.
LOCAL opCodeFrac IS totalCalls / CONFIG:IPU * 0.02.


LOCAL roundingFunctions IS LIST(ROUND@,FLOOR@,CEILING@).
LOCAL num TO 12.34.
LOCAL ll  TO 3.
LOCAL tl  TO 3.
LOCAL pls TO TRUE.
LOCAL rt  TO 0.

WAIT 0.
LOCAL startTime IS TIME:SECONDS.
FROM { LOCAL i IS 0. } UNTIL i >= totalCalls STEP { SET i TO i + 1. } DO {
padding1(num, ll, tl, pls, rt).
}
LOCAL tDelta IS TIME:SECONDS - startTime.
PRINT "Function A".
PRINT "   Execution Time: " + ROUND(tDelta,2).
PRINT "Estimated OPcodes: " + ROUND(tDelta / opCodeFrac - 12).//the loop it's self takes approximately 12 OPcodes
PRINT " ".

WAIT 0.
LOCAL startTime IS TIME:SECONDS.
FROM { LOCAL i IS 0. } UNTIL i >= totalCalls STEP { SET i TO i + 1. } DO {
padding2(num, ll, tl, pls, rt).
}
LOCAL tDelta IS TIME:SECONDS - startTime.
// LOCAL OPcodeDelta TO OPCODESLEFT - startOPcodes.
PRINT "Function B".
PRINT "   Execution Time: " + ROUND(tDelta,2).
PRINT "Estimated OPcodes: " + ROUND(tDelta / opCodeFrac - 12).//the loop it's self takes approximately 12 OPcodes
PRINT padding1(num, ll, tl, pls, rt) = padding2(num, ll, tl, pls, rt).

FUNCTION padding1 {
	PARAMETER num, leadingLength, trailingLength, positiveLeadingSpace IS TRUE, roundType IS 0.

	LOCAL returnString IS ABS(roundingFunctions[roundType](num,trailingLength)):TOSTRING.

	IF trailingLength > 0 {
		IF returnString:CONTAINS(".") {
			LOCAL splitString IS returnString:SPLIT(".").
			SET returnString TO (splitString[0]:PADLEFT(leadingLength) + "." + splitString[1]:PADRIGHT(trailingLength)):REPLACE(" ","0").
		} ELSE {
			SET returnString TO (returnString:PADLEFT(leadingLength) + "." + "0":PADRIGHT(trailingLength)):REPLACE(" ","0").
		}
	} ELSE IF returnString:LENGTH < leadingLength {
		SET returnString TO returnString:PADLEFT(leadingLength):REPLACE(" ","0").
	}

	IF num < 0 {
		RETURN "-" + returnString.
	} ELSE {
		IF positiveLeadingSpace {
			RETURN " " + returnString.
		} ELSE {
			RETURN returnString.
		}
	}
}

FUNCTION padding2 {
	PARAMETER num, leadingLength, trailingLength, positiveLeadingSpace IS TRUE, roundType IS 0.

	LOCAL returnString IS ABS(roundingFunctions[roundType](num,trailingLength)):TOSTRING.

	IF trailingLength > 0 {
		IF returnString:CONTAINS(".") {
			SET returnString TO returnString:PADLEFT(returnString:LENGTH + (leadingLength - returnString:INDEXOF("."))).
			SET returnString TO (returnString:PADRIGHT(returnString:LENGTH + (trailingLength - (returnString:LENGTH - 1 - returnString:INDEXOF(".")))):REPLACE(" ","0")).
		} ELSE {
			SET returnString TO (returnString:PADLEFT(leadingLength) + "." + "0":PADRIGHT(trailingLength)):REPLACE(" ","0").
		}
	} ELSE IF returnString:LENGTH < leadingLength {
		SET returnString TO returnString:PADLEFT(leadingLength):REPLACE(" ","0").
	}

	IF num < 0 {
		RETURN "-" + returnString.
	} ELSE {
		IF positiveLeadingSpace {
			RETURN " " + returnString.
		} ELSE {
			RETURN returnString.
		}
	}
}