SET STEERINGMANAGER:ROLLCONTROLANGLERANGE TO 180.
SET STEERINGMANAGER:PITCHTS TO 0.2.
SET STEERINGMANAGER:YAWTS TO 0.2.
SET STEERINGMANAGER:ROLLTS TO 0.2.

SET STEERINGMANAGER:PITCHTORQUEFACTOR TO 0.5.
SET STEERINGMANAGER:YAWTORQUEFACTOR TO 0.5.
SET STEERINGMANAGER:ROLLTORQUEFACTOR TO 0.5.

LOCAL localMU IS SHIP:BODY:MU.

LOCAL interface IS GUI(200).
 LOCAL iLeanBox IS interface:ADDVBOX().
  LOCAL ilbLable IS iLeanBox:ADDLABEL("Set Lean").
  LOCAL ilbLean IS iLeanBox:ADDHSLIDER(0,10,-10).
  LOCAL ilbReset IS iLeanBox:ADDBUTTON("Recenter Lean").
 LOCAL iThrottleBox IS interface:ADDVBOX().
  LOCAL itbLable IS iThrottleBox:ADDLABEL("Set Speed").
  LOCAL itbSpeedTar IS iThrottleBox:ADDTEXTFIELD("0").
  LOCAL itbSpeedUpdate IS iThrottleBox:ADDBUTTON("Update Throttle").
 LOCAL iDone IS interface:ADDBUTTON("Done").

SET ilbReset:ONCLICK TO { SET ilbLean:VALUE TO 0. }.
LOCAL stopping IS FALSE.
SET iDone:ONCLICK TO {
	SET stopping TO TRUE.
	update_throttle().
	SET lean TO 0.
	SET ilbLean:VALUE TO 0.
	WHEN (SHIP:VELOCITY:SURFACE:MAG < 0.1) AND (ABS(lean) < 0.1) THEN { SET done TO TRUE. }
}.
SET itbSpeedUpdate:ONCLICK TO update_throttle@.


LOCAL throttlePID IS PIDLOOP(0.5,0.2,0.02,-1,1).

interface:SHOW.

LOCAL upVec IS UP:VECTOR.//up vec will be normal to dir
LOCAL foreVec IS VXCL(upVec,SHIP:FACING:FOREVECTOR + SHIP:VELOCITY:SURFACE).
SAS OFF.
GEAR OFF.
LOCK STEERING TO LOOKDIRUP(foreVec,upVec).

//LOCAL v1 IS VECDRAW(SHIP:POSITION, UP:FOREVECTOR * 10,RED,"fore",1,TRUE,0.2).
//LOCAL v2 IS VECDRAW(SHIP:POSITION, UP:TOPVECTOR * 10,GREEN,"top",1,TRUE,0.2).
//LOCAL v3 IS VECDRAW(SHIP:POSITION, UP:STARVECTOR * 10,BLUE,"star",1,TRUE,0.2).

LOCAL lean IS 0.
LOCAL horizDist IS 0.

//tan(leanAng) = horizDist/vertDist
//horizDist * g = sideAccel

LOCAL done IS FALSE.
LOCAL pastTime IS TIME:SECONDS.
RCS OFF.
WAIT 0.
UNTIL RCS OR done {
	LOCAL localTime IS TIME:SECONDS.
	LOCAL deltaTime IS localTime - pastTime.
	SET pastTime TO localTime.
	
	LOCAL upDir IS UP.
	LOCAL vertVec IS upDir:FOREVECTOR.
	LOCAL facingFore IS SHIP:FACING:FOREVECTOR.
	LOCAL facingUp IS SHIP:FACING:TOPVECTOR.
	LOCAL forSpeed IS signed_speed().
	
	LOCAL facingFlat IS VXCL(vertVec,SHIP:FACING:FOREVECTOR):NORMALIZED.
	LOCAL flatVec IS VXCL(vertVec,facingFlat + SHIP:VELOCITY:SURFACE):NORMALIZED.
	
	//LOCAL flatVec IS VXCL(vertVec,facingFore):NORMALIZED.
	LOCAL starVec IS VCRS(flatVec,vertVec):NORMALIZED.
	
	LOCAL leanVec IS VXCL(flatVec,facingUp).
	LOCAL curLean IS VANG(vertVec,leanVec).
	IF VDOT(leanVec,starVec) < 0 {
		SET curLean TO -curLean.
	}
	CLEARSCREEN.
	PRINT lean.
	IF lean <> 0 {
		SET horizDist TO (SHIP:POSITION - SHIP:GEOPOSITION:POSITION):MAG * TAN(lean).//calculation the distance between the wheel contact and the COM along the ground
	} ELSE {
		SET horizDist TO 0.
	}
	PRINT horizDist.
	LOCAL localG IS localMU / (BODY:POSITION - SHIP:POSITION):SQRMAGNITUDE.
	LOCAL sideAccel IS localG * horizDist.
	PRINT sideAccel.
	
	LOCAL steerVec IS flatVec * forSpeed + starVec * sideAccel.
	
	IF forSpeed < 0 {
		SET steerVec TO -steerVec.
	}
	
	SET starVec TO VCRS(steerVec,vertVec):NORMALIZED.//adjusting star vector 
	
	
	//LOCAL lean IS 20.//the left, right lean amount in degrees, positive is left negative is right
	LOCAL leanCap IS MIN(ABS(forSpeed) * 10,10).
	SET lean TO lean + MIN(MAX(ilbLean:VALUE - lean,-10 * deltaTime),10 * deltaTime).
	//PRINT ROUND(lean,2) + "    " AT(0,0).
	SET upDir TO ANGLEAXIS(MIN(MAX(lean,-leanCap),leanCap),flatVec) * upDir.
	
	

	SET SHIP:CONTROL:WHEELTHROTTLE TO throttlePID:UPDATE(localTime,forSpeed).
	SET speedDif TO throttlePID:SETPOINT - forSpeed.
	//brake_check(speedDif,forSpeed).
	
	//LOCAL rock IS 0.//the forward, back lean in degrees 
	//SET upDir TO ANGLEAXIS(rock,starVec) * upDir.
	
	SET upVec TO upDir:FOREVECTOR.
	IF ABS(forSpeed) > 1 {
		IF forSpeed >= 0 {
			SET foreVec TO VCRS(upVec,starVec).
		} ELSE {
			SET foreVec TO VCRS(starVec,upVec).
		}
	} ELSE {
		SET foreVec TO facingFlat.
	}
	
	//SET v1:VEC TO foreVec:NORMALIZED * 10.
	//SET v2:VEC TO upVec * 10.
	//SET v3:VEC TO starVec * 10.
	WAIT 0.
}
UNLOCK STEERING.
SAS ON.
interface:DISPOSE.
CLEARVECDRAWS().
CLEARGUIS().
SET SHIP:CONTROL:WHEELTHROTTLE TO 0.
STEERINGMANAGER:RESETTODEFAULT().
GEAR ON.
WAIT 5.
SAS OFF.

FUNCTION update_throttle {
	IF NOT stopping {
		LOCAL setPointStr IS field_to_numbers_only(itbSpeedTar).
		SET throttlePID:SETPOINT TO setPointStr:TONUMBER(0).
		SET itbSpeedTar:TEXT TO setPointStr.
	} ELSE {
		SET throttlePID:SETPOINT TO 0.
	}
}

FUNCTION signed_speed {	//the speed of the rover positive for forward movement negative for reverse movement
	LOCAL shipVel IS SHIP:VELOCITY:SURFACE.
	IF VDOT(shipVel,SHIP:FACING:FOREVECTOR) > 0 {
		RETURN shipVel:MAG.
	} ELSE {
		RETURN -shipVel:MAG.
	}
}

FUNCTION brake_check {	//a check for over speed to turn on the brakes
	PARAMETER speedDif,forSpeed.
	IF speedDif < 0 AND SHIP:CONTROL:WHEELTHROTTLE = -1 {
		BRAKES ON.
	} ELSE { IF forSpeed < -0.5 {
			BRAKES ON.
		} ELSE {
			BRAKES OFF.
		}
	}
}

FUNCTION field_to_numbers_only {
	PARAMETER field,removeEndDP IS FALSE.
	LOCAL didChange IS FALSE.
	LOCAL localString IS field:TEXT.
	//IF localString:MATCHESPATTERN("([A-z]?)\w") {
	LOCAL dpLocation IS 0.
	FROM {LOCAL i IS localString:LENGTH - 1.} UNTIL i < 0 STEP {SET i TO i - 1.} DO {
		//IF NOT varConstants["numList"]:CONTAINS(localString[i]) {
		IF NOT localString[i]:MATCHESPATTERN("[0-9]") {
			IF localString[i] = "." {
				IF dpLocation <> 0 {
					SET didChange TO TRUE.
					SET localString TO localString:REMOVE(dpLocation,1).
				}
				SET dpLocation TO i.
			} ELSE IF NOT (i = 0 AND localString[i] = "-" ) {
				SET didChange TO TRUE.
				SET localString TO localString:REMOVE(i,1).
			}
		}
	}
	IF removeEndDP AND (dpLocation = (localString:LENGTH - 1)) {
		SET didChange TO TRUE.
		localString:REMOVE(localString:LENGTH - 1,1).
	}
	IF localString:LENGTH = 0 {
		SET didChange TO TRUE.
		SET localString TO "0".
	}
	//}
	IF didChange {
		RETURN localString.
	} ELSE {
		RETURN field:TEXT.
	}
}