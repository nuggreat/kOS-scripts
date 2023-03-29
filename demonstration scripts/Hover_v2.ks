PARAMETER tarAlt TO 1000.
LOCAL velCoef TO 1.
LOCAL accelCoef TO 1.
LOCAL accel TO 0.
LOCAL sign TO 1.
LOCAL tSpeed TO 0.
LOCAL rampDuration TO 5.
LOCAL rampDurSquared TO rampDuration^2.
LOCAL rampDurCubed TO rampDuration^3.
LOCAL engList SHIP:ENGINES.

LOCAL throtPID TO PIDLOOP(1,0.1,0.1,0,1).
SET throtPID:SETPOINT TO tSpeed.
LOCAL bMU TO SHIP:BODY:MU.
LOCK THROTTLE TO throtPID:UPDATE(TIME:SECONDS,current_thrust()/SHIP:MASS).
LOCK STEERING TO UP.
LOCAL sufGrav TO bMU / BODY:RADIUS^2.
CLEARSCREEN.
RCS OFF.
UNTIL RCS {
    LOCAL distError TO tarAlt - SHIP:ALTITUDE.
	LOCAL lGrav TO (bMU / (SHIP:POSITION - BODY:POSITION):SQRMAGNITUDE).
    IF distError > 0 {//below tarAlt
        SET accel TO sufGrav.
        SET sign TO 1.
    } ELSE {//above or at tarAlt
        SET accel TO SHIP:AVAILABLETHRUST * 0.5 / SHIP:MASS - sufGrav.
        SET sign TO -1.
    }
	LOCAL locCoef TO CHOOSE accelCoef IF ABS(distError) > -100 ELSE 0.01.
    LOCAL tSpeed TO SQRT(ABS(2 * distError * ramp_accel(ABS(distError),accel) * locCoef)) * sign * velCoef.
    //LOCAL tSpeed TO ramp_accel(ABS(distError),accel) * sign.
	SET throtPID:SETPOINT TO ((tSpeed - SHIP:VERTICALSPEED) + lGrav).
	//CLEARSCREEN.
	PRINT tSpeed + "     " AT(0,0).
	PRINT distError + "     " AT(0,1).
	pid_debug(throtPID).
    WAIT 0.
}

//PARAMETER ac,di.
//LOCAL rampDuration TO 5.
//LOCAL rampDurSquared TO rampDuration^2.
//ramp_accel(ac,di).

FUNCTION ramp_accel {
	PARAMETER dError,baseAcc.
	LOCAL j TO baseAcc / rampDuration.
	LOCAL rampDist TO 1/6 * j * rampDurCubed.
	IF rampDist < dError {
		LOCAL rampSpeed TO 1/2 * j * rampDurSquared.
		//full duration dervies from `distance = initalSpeed * time + acceleration * time^2
		LOCAL fullDuration TO (SQRT(2 * baseAcc * (dError - rampDist) + rampSpeed^2) - rampSpeed) / baseAcc.
		RETURN (baseAcc * fullDuration + rampSpeed) / (rampDuration + fullDuration).//average accel
		//RETURN (baseAcc * fullDuration + rampSpeed).
		
		// d = total - ramp
		// x = initalVel
		// v = rampVel
		// 2ad + x^2 = v^2
		// x^2 = v^2 - 2ad
		// x = SQRT(v^2 - 2ad)
		
		// x - v / a = t
		
		//SQRT(2 * a * (d - b) + s^2) - s)
		
		//PRINT 1 / ((rampDuration / SQRT( baseAcc * (8 * dError - baseAcc * rampDuration^2))) + (1 / baseAcc)).
		
		
		//a = baseAcc
		//r = rampDuration
		//d = dError
		//i = 25
			
		//LOCAL rampAccel TO (a / 2).
		//LOCAL rampDist TO ((a / 2) / 2 * r^2).
		//LOCAL rampSpeed TO (r * (a / 2)).
		//LOCAL fullDuration TO ((SQRT(2*a*(d - ((a / 2) / 2 * r^2))+(r * (a / 2))^2) - (r * (a / 2))) / a).
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
		LOCAL jDuration TO (dError * 6 / j)^(1/3).
		//d / t  = s
		//dist = initalDist + initalVel * time + initalAccel / 2 * time^2 + initalJerk / 6 * time^3
		//PRINT dError * 2 / jDuration^2.
		RETURN jDuration * j / 2.//average acceleration
		//RETURN 1/2 * j * jDuration^2.//targetSpeed
	}
}

FUNCTION current_thrust {
	LOCAL curThrust TO 0.
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

// very damped hover script
// parameter target_alt TO 1000, settleTime TO 30, damp TO 1.

// SAS OFF.
// function v_accel {
	// CLEARSCREEN.
    // local altError is target_alt - altitude.
    // local cenAccel is vxcl(up:vector, velocity:orbit):sqrmagnitude / body:position:mag.
    // local g is body:mu / body:position:sqrmagnitude.
	// LOCAL accMod TO -verticalspeed^2 / (2 * altError).
    // local vert_accel is 2 * (altError - verticalspeed * damp * settleTime) / settleTime^2.
    // return res.
    // return g - cenAccel + vert_accel + accMod.
// }

// LOCK maxAccel TO ship:availablethrust / ship:mass.
// lock steering to LOOKDIRUP(UP:VECTOR * MAX(SHIP:VELOCITY:SURFACE:MAG,1) * 10 - SHIP:VELOCITY:SURFACE,NORTH:VECTOR).
// lock throttle to v_accel / maxAccel.

// RCS OFF.
// WAIT UNTIL RCS.
// SET SHIP:CONTROL:PILOTMAINTHROTTLE TO throttle.
// SAS ON.