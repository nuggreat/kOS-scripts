@LAZYGLOBAL OFF.

LOCAL FUNCTION time_converter {
	PARAMETER timeValue, places.
	SET timeValue TO TIMESPAN(timeValue).

	IF timeValue:MINUTES < 1 OR places = 1 {
		RETURN LIST(ROUND(timeValue:SECONDS,2)).

	} ELSE IF timeValue:HOURS < 1 OR places = 2 {
		RETURN LIST(ROUND(MOD(timeValue:SECONDS,60),2), timeValue:MINUTES).

	} ELSE IF timeValue:DAYS < 1 OR places = 3 {
		RETURN LIST(ROUND(MOD(timeValue:SECONDS,60),2), timeValue:MINUTE, timeValue:HOURS).

	} ELSE IF timeValue:YEARS < 1 OR places = 4 {
		RETURN LIST(ROUND(MOD(timeValue:SECONDS,60),2), timeValue:MINUTE, timeValue:HOUR, timeValue:DAYS).

	} ELSE {
		RETURN LIST(ROUND(MOD(timeValue:SECONDS,60),2), timeValue:MINUTE, timeValue:HOUR, timeValue:DAY, timeValue:YEARS).
	}
}

LOCAL timeFormats IS LIST().
timeFormats:ADD(LIST(0,LIST("s","m ","h ","d ","y "),2)).
timeFormats:ADD(LIST(0,LIST("",":",":"," Days, "," Years, "),2)).
timeFormats:ADD(LIST(0,LIST(" Seconds"," Minutes, "," Hours, "," Days, "," Years, "),2)).
timeFormats:ADD(LIST(0,LIST("",":",":"),2)).
timeFormats:ADD(LIST(3,timeFormats[3][1],2)).
timeFormats:ADD(LIST(2,LIST("s  ","m  ","h  ","d ","y "),0)).
timeFormats:ADD(LIST(2,LIST(" Seconds  "," Minutes  "," Hours    "," Days    "," Years   "),0)).

LOCAL leading0List IS LIST(2,2,2,3,3).//presumed maximum leading zeros applied to sec,min,hour,day,year values

FUNCTION time_formatting {
	PARAMETER timeSec, formatType IS 0, rounding IS 0, prependT IS FALSE, showPlus IS prependT.

	LOCAL timeFormat IS timeFormats[formatType].
	LOCAL fixedPlaces IS timeFormat[0].
	LOCAL stringList IS timeFormat[1].

	LOCAL roundingList IS LIST(MIN(rounding,timeFormat[2]), 0, 0, 0, 0).
	SET timeSec TO ROUND(timeSec, roundingList[0]).

	LOCAL maxPlaces IS stringList:LENGTH.
	LOCAL timeList IS time_converter(ABS(timeSec), maxPlaces).
	LOCAL maxLength IS MIN(timeList:LENGTH, maxPlaces).
	LOCAL returnString IS "".

	IF fixedPlaces > 0 {
		UNTIL timeList:LENGTH >= fixedPlaces {
			timeList:ADD(0).
		}
		SET maxLength TO MIN(timeList:LENGTH, maxPlaces).
	} ELSE {
		SET fixedPlaces TO maxLength.
	}

	FROM {LOCAL i IS maxLength - fixedPlaces.}
	UNTIL i >= maxLength STEP {SET i TO i + 1.} DO {
		LOCAL paddedStr IS padding(timeList[i], leading0List[i], roundingList[i], FALSE, 1).
		SET returnString TO paddedStr + stringList[i] + returnString.
	}

	IF prependT SET returnString TO returnString:INSERT(0, " ").

	IF timeSec < 0 {
		SET returnString TO returnString:INSERT(0, "-").
	} ELSE IF showPlus {
		SET returnString TO returnString:INSERT(0, "+").
	} ELSE {
		SET returnString TO returnString:INSERT(0, " ").
	}

	IF prependT SET returnString TO returnString:INSERT(0, "T").

	RETURN returnString.
}


LOCAL siPrefixList IS LIST(" y"," z"," a"," f"," p"," n"," μ"," m","  "," k"," M"," G"," T"," P"," E"," Z"," Y").

FUNCTION si_formatting {
	PARAMETER num, unit IS "".

	IF num = 0 {
		RETURN padding(num,1,3) + "  " + unit.
	} ELSE {
		LOCAL powerOfTen IS MAX(MIN(FLOOR(LOG10(ABS(num))),26),-24).

		SET num TO ROUND(num/10^powerOfTen,3) * 10^powerOfTen.

		SET powerOfTen TO MAX(MIN(FLOOR(LOG10(ABS(num))),26),-24).
		LOCAL SIfactor IS FLOOR(powerOfTen / 3).
		LOCAL trailingLength IS 3 - (powerOfTen - SIfactor * 3).

		LOCAL prefix IS siPrefixList[SIfactor + 8].
		RETURN padding(num/1000^SIfactor,1,trailingLength,TRUE,0) + prefix + unit.
	}
}


LOCAL roundingFunctions IS LIST(ROUND@,FLOOR@,CEILING@).

FUNCTION padding {
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