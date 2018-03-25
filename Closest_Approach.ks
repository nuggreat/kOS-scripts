PARAMETER startingTime IS TIME:SECONDS.

LOCAL tarBody TO TARGET.
LOCAL timeStep IS 8640.
IF distance_at_time(startingTime,tarBody) > 90000000 {
	SET timeStep TO timeStep * 100.
}
LOCAL initalTimeStep IS timeStep.
LOCAL etaEstmation IS startingTime.


// Do the hill climbing
set approachTime to startingTime.
UNTIL timeStep < 0.1 {

	LOCAL pos IS distance_at_time(approachTime + timeStep, tarBody).
	LOCAL equ IS distance_at_time(approachTime, tarBody).
	LOCAL neg IS distance_at_time(approachTime - timeStep, tarBody).
	
	IF (pos < equ) OR (neg < equ) {
		IF pos < neg {
		SET approachTime TO approachTime + timeStep.
		} ELSE {
			SET approachTime TO approachTime - timeStep.
		}
		SET etaEstmation to (approachTime - TIME:SECONDS).
	} ELSE {
		SET timeStep TO (timeStep / 2).
	}
	
	CLEARSCREEN.
	PRINT "closest approach ETA: " + time_converter(etaEstmation).
	IF (approachTime - TIME:SECONDS) < 0 {
		SET timeStep TO initalTimeStep.
		SET startingTime TO startingTime + timeStep * 10.
		SET approachTime TO startingTime.
	}
}

IF (approachTime - TIME:SECONDS) < 0 {
	PRINT "Error, current position is closest approach".
} ELSE {
	CLEARSCREEN.
	PRINT "Closest approach distance is: " + si_formatting(distance_at_time(approachTime,tarBody),"km").
	PRINT "---------------------------------------------------------".
	PRINT "Closest approach ETA is in:   " + time_converter(etaEstmation).
	PRINT "---------------------------------------------------------".
	PRINT "Closest approach is at:       " + time_converter(etaEstmation + TIME:SECONDS).
}

//end of core logic
FUNCTION distance_at_time {
  PARAMETER t, TarBody.
  RETURN ((POSITIONAT(SHIP, t) - POSITIONAT(TarBody, t)):MAG).
}

FUNCTION time_converter {
	PARAMETER timeSec,rounding IS 0,tMinus IS FALSE.
	LOCAL localTime IS ROUND(ABS(timeSec),rounding).
	LOCAL hoursInDay IS 24.
	LOCAL daysInYear IS 365.

	LOCAL returnString IS padding(MOD(localTime,60),2,rounding) + "s".
	SET localTime TO (localTime - MOD(localTime,60)) / 60.
	IF localTime > 0 {	
		SET returnString TO padding(MOD(localTime,60),2,0) + "m" + returnString.
		SET localTime TO (localTime - MOD(localTime,60)) / 60.
	}
	IF localTime > 0 {
		SET returnString TO padding(MOD(localTime,hoursInDay),2,0) + "h" + returnString.
		SET localTime TO (localTime - MOD(localTime,hoursInDay)) / hoursInDay.
	}
	IF localTime > 0 {
		SET returnString TO padding(MOD(localTime,daysInYear),3,0) + "d" + returnString.
		SET localTime TO (localTime - MOD(localTime,daysInYear)) / daysInYear.
	}
	IF localTime > 0 {
		SET returnString TO localTime + "y" + returnString.
	}
	
	IF timeSec < 0 {
		SET returnString TO returnString:INSERT(1,"-").
		IF tMinus {
			SET returnString TO returnString:INSERT(1,"T- ").
		}
	} ELSE IF tMinus {
		SET returnString TO returnString:INSERT(1,"T+ ").
	}
	RETURN returnString.
}

FUNCTION si_formatting {
	PARAMETER num,//number to format,
	unit,//unit of number
	trailingLength IS 2,//number of places after decimal point
	leadingLenght IS 1.//number of places before decimal point
	LOCAL powerOfTen IS FLOOR(LOG10(ABS(num)) / 3).
	LOCAL prefix IS LIST(" y"," z"," a"," f"," p"," n"," μ"," m","  "," k"," M"," G"," T"," P"," E"," Z"," Y")[powerOfTen + 8].
	RETURN padding(num/1000^powerOfTen,leadingLenght,trailingLength) + prefix + unit.
}

FUNCTION padding {
	PARAMETER num,leadingLenght,trailingLength.//number to pad,min length before decimal point, length after decimal point
	LOCAL returnString IS ABS(ROUND(num,trailingLength)):TOSTRING.
	
	IF trailingLength > 0 {
		IF NOT returnString:CONTAINS(".") {
			SET returnString TO returnString + ".0".
		}
		UNTIL returnString:SPLIT(".")[1]:LENGTH >= trailingLength { SET returnString TO returnString + "0". }
		UNTIL returnString:SPLIT(".")[0]:LENGTH >= leadingLenght { SET returnString TO "0" + returnString. }
	} ELSE {
		UNTIL returnString:LENGTH >= leadingLenght { SET returnString TO "0" + returnString. }
	}
	
	IF num < 0 {
		RETURN "-" + returnString.
	} ELSE {
		RETURN " " + returnString.
	}
}