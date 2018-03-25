CLEARSCREEN.
PRINT "Finding Next Oclusion Crossing".
LOCAL curentOclusion IS solar_oclusion_at_time().
PRINT curentOclusion.
LOCAL scanMax IS TIME:SECONDS + SHIP:ORBIT:PERIOD.
LOCAL scanStartTime IS TIME:SECONDS.
LOCAL scanTime IS scanStartTime.
LOCAL stepSizeStart IS 3.
LOCAL stepSize IS stepSizeStart.
LOCAL stepIncrement IS SHIP:ORBIT:PERIOD.
LOCAL done IS FALSE.
UNTIL done {
	LOCAL testedTime IS solar_oclusion_at_time(scanTime).
	LOCAL stepValue IS stepIncrement / 2^stepSize.
	IF testedTime = curentOclusion {
		SET scanTime TO scanTime + stepValue.
		SET stepSize TO stepSize - 0.01.
	} ELSE {
		SET scanTime TO scanTime - stepValue.
		SET stepSize TO stepSize + 0.1.
	}
	IF stepValue < 0.1 { SET done TO TRUE. }
	IF scanTime > scanMax {
		SET scanTime TO scanStartTime.
		SET stepSizeStart TO stepSizeStart + 1.
		SET stepSize TO stepSizeStart.
		PRINT "reset".
		WAIT 1.
	}
	PRINT ROUND(stepValue,4).
	PRINT ROUND(scanTime,4).
	PRINT testedTime.
	PRINT curentOclusion.
	WAIT 0.
	CLEARSCREEN.
}
PRINT "Next Oclusion Crossing is in: " + ROUND(scanTime - TIME:SECONDS,2) + "s".

FUNCTION solar_oclusion_at_time { //return true if sun will be blocked at given UTC
	PARAMETER timeIn IS TIME:SECONDS.
	LOCAL pos_sun IS POSITIONAT(BODY("SUN"),timeIn).
	LOCAL pos_ship IS POSITIONAT(SHIP,timeIn).
	LOCAL pos_body IS POSITIONAT(SHIP:BODY,timeIn).
	LOCAL vec_sun_body IS pos_body - pos_sun.
	LOCAL vec_sun_ship IS pos_ship - pos_sun.
	LOCAL shade_angle IS ARCSIN(SHIP:BODY:RADIUS/vec_sun_body:MAG).
	LOCAL returnValue IS (VANG(vec_sun_body,vec_sun_ship) < shade_angle) AND (vec_sun_ship:MAG > vec_sun_body:MAG).
	PRINT shade_angle.
	PRINT VANG(vec_sun_body,vec_sun_ship).
	IF returnValue {
		PRINT "DARKNESS".
	} ELSE {
		PRINT "SUNLIGHT".
	}
	RETURN returnValue.
}