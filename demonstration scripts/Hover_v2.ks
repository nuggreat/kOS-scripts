PARAMETER tarAlt IS 1000.
LOCAL velCoef IS 1.
LOCAL accelCoef IS 1.
LOCAL accel IS 0.
LOCAL sign IS 1.
LOCAL tSpeed IS 0.
LOCAL rampDuration IS 5.
LOCAL rampDurSquared IS rampDuration^2.
LOCAL rampDurCubed IS rampDuration^3.
LOCAL engList IS LIST().
LIST ENGINES IN engList.

LOCAL throtPID IS PIDLOOP(1,0.1,0.1,0,1).
SET throtPID:SETPOINT TO tSpeed.
LOCAL bMU IS SHIP:BODY:MU.
LOCK THROTTLE TO throtPID:UPDATE(TIME:SECONDS,current_thrust()/SHIP:MASS).
LOCK STEERING TO UP.
LOCAL sufGrav IS bMU / BODY:RADIUS^2.
CLEARSCREEN.
RCS OFF.
UNTIL RCS {
    LOCAL distError IS tarAlt - SHIP:ALTITUDE.
	LOCAL lGrav IS (bMU / (SHIP:POSITION - BODY:POSITION):SQRMAGNITUDE).
    IF distError > 0 {//below tarAlt
        SET accel TO sufGrav.
        SET sign TO 1.
    } ELSE {//above or at tarAlt
        SET accel TO SHIP:AVAILABLETHRUST * 0.5 / SHIP:MASS - sufGrav.
        SET sign TO -1.
    }
	LOCAL locCoef IS CHOOSE accelCoef IF ABS(distError) > -100 ELSE 0.01.
    LOCAL tSpeed IS SQRT(ABS(2 * distError * ramp_accel(ABS(distError),accel) * locCoef)) * sign * velCoef.
    //LOCAL tSpeed IS ramp_accel(ABS(distError),accel) * sign.
	SET throtPID:SETPOINT TO ((tSpeed - SHIP:VERTICALSPEED) + lGrav).
	//CLEARSCREEN.
	PRINT tSpeed + "     " AT(0,0).
	PRINT distError + "     " AT(0,1).
	pid_debug(throtPID).
    WAIT 0.
}

//PARAMETER ac,di.
//LOCAL rampDuration IS 5.
//LOCAL rampDurSquared IS rampDuration^2.
//ramp_accel(ac,di).

FUNCTION ramp_accel {
	PARAMETER dError,baseAcc.
	LOCAL j IS baseAcc / rampDuration.
	LOCAL rampDist IS 1/6 * j * rampDurCubed.
	IF rampDist < dError {
		LOCAL rampSpeed IS 1/2 * j * rampDurSquared.
		//full duration dervies from `distance = initalSpeed * time + acceleration * time^2
		LOCAL fullDuration IS (SQRT(2 * baseAcc * (dError - rampDist) + rampSpeed^2) - rampSpeed) / baseAcc.
		RETURN (baseAcc * fullDuration + rampSpeed) / (rampDuration + fullDuration).//average accel
		//RETURN (baseAcc * fullDuration + rampSpeed).
		
		//PRINT 1 / ((rampDuration / SQRT( baseAcc * (8 * dError - baseAcc * rampDuration^2))) + (1 / baseAcc)).
		
		
		//a = baseAcc
		//r = rampDuration
		//d = dError
		//i = 25
			
		//LOCAL rampAccel IS (a / 2).
		//LOCAL rampDist IS ((a / 2) / 2 * r^2).
		//LOCAL rampSpeed IS (r * (a / 2)).
		//LOCAL fullDuration IS ((SQRT(2*a*(d - ((a / 2) / 2 * r^2))+(r * (a / 2))^2) - (r * (a / 2))) / a).
		//RETURN (a * ((SQRT(2*a*(d - ((a / 2) / 2 * r^2))+(r * (a / 2))^2) - (r * (a / 2))) / a) + (r * (a / 2))) / (r + ((SQRT(2*a*(d - ((a / 2) / 2 * r^2))+(r * (a / 2))^2) - (r * (a / 2))) / a)).
		//1 / ((rampDuration / SQRT( baseAcc * (8 * dError - baseAcc * rampDuration^2))) + (1 / baseAcc))
		
	} ELSE {
		//1/6 * j * t^3 = d
		//j * t^3 = d * 6
		//t^3 = d * 6 / j
		//t = (d * 6 / j)^(1/3)
		
		//PRINT 1/6 * j * 5^3.
		//PRINT baseAcc / 4 * 5^2.
		//PRINT " ".
		LOCAL jDuration IS (dError * 6 / j)^(1/3).
		//d / t  = s
		//dist = initalDist + initalVel * time + initalAccel / 2 * time^2 + initalJerk / 6 * time^3
		//PRINT dError * 2 / jDuration^2.
		RETURN jDuration * j / 2.//average acceleration
		//RETURN 1/2 * j * jDuration^2.//targetSpeed
	}
}

FUNCTION current_thrust {
	LOCAL curThrust IS 0.
	FOR eng IN engList {
		SET curThrust TO eng:THRUST + curThrust.
	}
	RETURN curThrust.
}

FUNCTION pid_debug {
	PARAMETER pidToDebug.
	//CLEARSCREEN.
	PRINT "Setpoint: " + ROUND(pidToDebug:SETPOINT,2) + "     " AT(0,2).
	PRINT "   Error: " + ROUND(pidToDebug:ERROR,2) + "     " AT(0,3).
	PRINT "       P: " + ROUND(pidToDebug:PTERM,3) + "      " AT(0,4).
	PRINT "       I: " + ROUND(pidToDebug:ITERM,3) + "      " AT(0,5).
	PRINT "       D: " + ROUND(pidToDebug:DTERM,3) + "      " AT(0,6).
	PRINT "     Max: " + ROUND(pidToDebug:MAXOUTPUT,2) + "     " AT(0,7).
	PRINT "  Output: " + ROUND(pidToDebug:OUTPUT,2) + "     " AT(0,8).
	PRINT "     min: " + ROUND(pidToDebug:MINOUTPUT,2) + "     " AT(0,9).
//	LOG (pidToDebug:SETPOINT + "," + pidToDebug:ERROR + "," + pidToDebug:PTERM + "," + pidToDebug:ITERM + "," + pidToDebug:DTERM + "," + pidToDebug:MAXOUTPUT + "," + pidToDebug:OUTPUT +  "," + pidToDebug:MINOUTPUT) TO PATH("0:/pidLog.txt").
}