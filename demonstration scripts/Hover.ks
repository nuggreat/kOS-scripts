CLEARSCREEN.
CLEARGUIS().
SAS OFF.
LOCAL tarAlt IS 1000.
LOCAL sign IS 1.
LOCAL gravOffset IS 0.
LOCAL engineAcc IS 1.
LOCAL sufGrav IS SHIP:BODY:MU / BODY:RADIUS^2.
LOCAL gravAcc IS sufGrav. 

LOCAL done IS FALSE.
LOCAL interface IS GUI(200).
LOCAL iLabel IS interface:ADDLABEL(tarAlt:TOSTRING).
LOCAL iField IS interface:ADDTEXTFIELD(tarAlt:TOSTRING).
LOCAL iAltUpdate IS interface:ADDBUTTON("update altitude").
SET iAltUpdate:ONCLICK TO {
	IF iField:TEXT:TONUMBER(0) = 0 {
		SET iField:TEXT TO tarAlt:TOSTRING.
	} ELSE {
		SET tarAlt TO iField:TEXT:TONUMBER(0).
		// SET gravAcc TO SHIP:BODY:MU / (BODY:RADIUS + tarAlt)^2.
	}
	SET iLabel:TEXT TO "Target Altitude: " + iField:TEXT.
}.

LOCAL iSteerLock IS interface:ADDBUTTON("Lock Steering").
SET iSteerLock:ONCLICK TO {
	IF iSteerLock:TEXT = "Lock Steering" {
		SET iSteerLock:TEXT TO "Unlock Steering".
		SAS OFF.
		LOCK STEERING TO LOOKDIRUP(UP:VECTOR - VXCL(UP:VECTOR,SHIP:VELOCITY:SURFACE * 0.01),NORTH:VECTOR).
	} ELSE {
		SET iSteerLock:TEXT TO "Lock Steering".
		UNLOCK STEERING.
		SAS ON.
	}
}.
iSteerLock:ONCLICK().

LOCAL iExitButton IS interface:ADDBUTTON("Quit").
SET iExitButton:ONCLICK TO {
	SET done TO TRUE.
}.

interface:SHOW.

LOCAL throtPID IS PIDLOOP(5,0.1,0.01,-1,1).
LOCAL throtlePIDbaseTuning IS LIST(5,.1,0.01).
pid_tune(throtPID,throtlePIDbaseTuning,1).
LOCK THROTTLE TO throtPID:UPDATE(TIME:SECONDS,SHIP:VERTICALSPEED) + gravOffset.
// LOCAL throt IS 0.
// LOCK THROTTLE TO throt / 10 + gravOffset.
// LOCK STEERING TO LOOKDIRUP(UP:VECTOR - VXCL(UP:VECTOR,SHIP:VELOCITY:SURFACE * 0.001),NORTH:VECTOR).
// LOCK STEERING TO UP.
LOCAL oldTime IS TIME:SECONDS.
WAIT 0.

RCS OFF.
UNTIL done {
	// LOCAL newTime IS TIME:SECONDS.
	// LOCAL dt IS newTime - oldTime.
	// SET oldTime TO newTime.
	LOCAL distError IS tarAlt - SHIP:ALTITUDE.// - SHIP:VERTICALSPEED * dt.
	LOCAL rad IS (SHIP:POSITION - SHIP:BODY:POSITION):MAG.
	LOCAL tiltError IS COS(VANG(UP:VECTOR,SHIP:FACING:FOREVECTOR)).
	SET engineAcc TO SHIP:AVAILABLETHRUST * tiltError / SHIP:MASS.
	SET gravAcc TO SHIP:BODY:MU / (rad * (rad + distError)).
	pid_tune(throtPID,throtlePIDbaseTuning,1/engineAcc).
	IF distError > 0 {//below tarAlt
		SET accel TO gravAcc.
		SET sign TO 1.
	} ELSE {//above or at tarAlt
		SET accel TO (engineAcc - sufGrav).
		SET sign TO -1.
	}
	SET gravOffset TO gravAcc / engineAcc.
	LOCAL tSpeed IS MIN(SQRT(MAX(ABS(1 * distError * accel),0.0001)), ABS(distError)) * sign.
	SET throtPID:SETPOINT TO tSpeed.
	// SET throt TO (throtPID:UPDATE(TIME:SECONDS,SHIP:VERTICALSPEED / engineAcc) + throt) / (11/10).
	pid_debug(throtPID).
	PRINT "distError: " + distError + "	  " AT(0,8).
	PRINT "vSpeed: " + SHIP:VERTICALSPEED + "	  " AT(0,9).
	//PRINT gravOffset AT(0,10).
	PRINT "gravValue: " + gravAcc + "	 " AT(0,11).
	WAIT 0.
}
SAS ON.
interface:CLEAR().

FUNCTION pid_tune {
	PARAMETER pid,baseTuning,factor.
	SET pid:Kp TO baseTuning[0] * factor.
	SET pid:Ki TO baseTuning[1] * factor.
	SET pid:Kd TO baseTuning[2] * factor.
}

FUNCTION pid_debug {
	PARAMETER pidToDebug.
	//CLEARSCREEN.
	PRINT "Setpoint: " + ROUND(pidToDebug:SETPOINT,2) + "	 " AT(0,0).
	PRINT "   Error: " + ROUND(pidToDebug:ERROR,2) + "	 " AT(0,1).
	PRINT "	   P: " + ROUND(pidToDebug:PTERM,3) + "	  " AT(0,2).
	PRINT "	   I: " + ROUND(pidToDebug:ITERM,3) + "	  " AT(0,3).
	PRINT "	   D: " + ROUND(pidToDebug:DTERM,3) + "	  " AT(0,4).
	PRINT "	 Max: " + ROUND(pidToDebug:MAXOUTPUT,2) + "	 " AT(0,5).
	PRINT "  Output: " + ROUND(pidToDebug:OUTPUT,2) + "	 " AT(0,6).
	PRINT "	 min: " + ROUND(pidToDebug:MINOUTPUT,2) + "	 " AT(0,7).
//	LOG (pidToDebug:SETPOINT + "," + pidToDebug:ERROR + "," + pidToDebug:PTERM + "," + pidToDebug:ITERM + "," + pidToDebug:DTERM + "," + pidToDebug:MAXOUTPUT + "," + pidToDebug:OUTPUT +  "," + pidToDebug:MINOUTPUT) TO PATH("0:/pidLog.txt").
}