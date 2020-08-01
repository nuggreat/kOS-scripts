FUNCTION pid_init_1 {
	PARAMETER kP,kI,kD,maxMag.
	LOCAL lastSampleTime IS TIME:SECONDS.
	LOCAL firstInput IS TRUE.
	LOCAL lastInput IS v(0,0,0).
	LOCAL lastError IS v(0,0,0).
	LOCAL lastOutput IS v(0,0,0).
	LOCAL lastErrorSum IS v(0,0,0).
	LOCAL lastPTerm IS v(0,0,0).
	LOCAL lastITerm IS v(0,0,0).
	LOCAL lastDTerm IS v(0,0,0).
	LOCAL lastChangeRate IS v(0,0,0).
	
	LOCAL pidLex IS LEX().
	pidLex:ADD("LASTSAMPLETIME",{ RETURN lastSampleTime.}).
	pidLex:ADD("kP",kP).
	pidLex:ADD("kI",kI).
	pidLex:ADD("kD",kD).
	pidLex:ADD("INPUT",{ RETURN lastInput.}).
	pidLex:ADD("SETPOINT",v(0,0,0)).
	pidLex:ADD("ERROR",{ RETURN lastError.}).
	pidLex:ADD("OUTPUT"{ RETURN lastOutput.}).
	pidLex:ADD("MAXOUTPUT",maxMag).
	pidLex:ADD("ERRORSUM",{ RETURN lastITerm / pidLex:kI.}).
	pidLex:ADD("PTERM",{ RETURN lastPTerm.}).
	pidLex:ADD("ITERM",{ RETURN lastITerm.}).
	pidLex:ADD("DTERM",{ RETURN lastDTerm.}).
	pidLex:ADD("CHANGERATE",{ RETURN lastChangeRate.}).
	
	pidLex:ADD("RESSET",{
		SET firstInput TO TRUE.
		SET lastInput TO v(0,0,0).
		SET lastError TO v(0,0,0).
		SET lastOutput TO v(0,0,0).
		SET lastErrorSum TO v(0,0,0).
		SET lastPTerm TO v(0,0,0).
		SET lastITerm TO v(0,0,0).
		SET lastDTerm TO v(0,0,0).
		SET lastChangeRate TO v(0,0,0).
	}).
	
	pidLex:ADD("UPDATE",{
	PARAMETER newSampleTime, newInput.
		IF newSampleTime <> lastSampleTime {
			LOCAL deltaT IS newSampleTime - lastSampleTime.
			LOCAL newError IS pidLex:SETPOINT - newInput.
			LOCAL newChangeRate IS (newInput - lastInput) / deltaT.
			
			IF firstInput {
				SET firstInput TO FALSE.
				SET newChangeRate TO v(0,0,0).
				SET deltaT TO 0.
			}
			
			LOCAL newPTerm IS newError * pidLex:kP.
			LOCAL newITerm IS lastITerm + (newError * pidLex:kI * deltaT).
			LOCAL newDTerm IS -newChangeRate * pidLex:kD.
			
			IF newITerm:MAG > (pidLex:maxMag - (newPTerm + newDTerm):MAG)  {
				SET newITerm:MAG TO pidLex:maxMag - ((newPTerm + newDTerm):MAG.
			}
			
			LOCAL newOutput IS newPTerm + newITerm + newDTerm.
			
			IF newOutput:MAG > pidLex:maxMag {
				SET newOutput:MAG TO pidLex:maxMag.
			}
			
			SET lastInput TO newInput.
			SET lastError TO newError.
			SET lastOutput TO newOutput.
			SET lastErrorSum TO newError.
			SET lastPTerm TO newPTerm.
			SET lastITerm TO newITerm.
			SET lastDTerm TO newDTerm.
			SET lastChangeRate TO newChangeRate.
			
			RETURN newOutput.
		} ELSE {
			RETURN lastOutput.
		}
	}).
}

FUNCTION pid_init_2 {
	PARAMETER kP,kI,kD,maxMag.
	LOCAL xPID IS PIDLOOP(kP,kI,kD,-maxMag, maxMag).
	LOCAL yPID IS PIDLOOP(kP,kI,kD,-maxMag, maxMag).
	LOCAL zPID IS PIDLOOP(kP,kI,kD,-maxMag, maxMag).
	LOCAL oldSetPoint IS v(0,0,0).
	LOCAL oldMaxMag IS maxMag
	
	LOCAL pidLex IS LEX().
	pidLex:ADD("LASTSAMPLETIME",{ RETURN xPID:LASTSAMPLETIME.}).
	pidLex:ADD("kP",kP).
	pidLex:ADD("kI",kI).
	pidLex:ADD("kD",kD).
	pidLex:ADD("INPUT",{ RETURN v(xPID:INPUT,yPID:INPUT,zPID:INPUT). }).
	pidLex:ADD("SETPOINT",v(0,0,0)).
	pidLex:ADD("ERROR",{ RETURN v(xPID:ERROR,yPID:ERROR,zPID:ERROR). }).
	pidLex:ADD("OUTPUT",{ RETURN v(xPID:OUTPUT,yPID:OUTPUT,zPID:OUTPUT). }).
	pidLex:ADD("MAXOUTPUT",maxMag).
	pidLex:ADD("ERRORSUM",{ RETURN v(xPID:ERRORSUM,yPID:ERRORSUM,zPID:ERRORSUM). }).
	pidLex:ADD("PTERM",{ RETURN v(xPID:PTERM,yPID:PTERM,zPID:PTERM). }).
	pidLex:ADD("ITERM",{ RETURN v(xPID:ITERM,yPID:ITERM,zPID:ITERM). }).
	pidLex:ADD("DTERM",{ RETURN v(xPID:DTERM,yPID:DTERM,zPID:DTERM). }).
	pidLex:ADD("CHANGERATE",{ RETURN v(xPID:CHANGERATE,yPID:CHANGERATE,zPID:CHANGERATE). }).
	
	pidLex:ADD("RESSET",{
		xPID:RESET().
		yPID:RESET().
		zPID:RESET().
	}).
	
	pidLex:ADD("UPDATE",{
	PARAMETER newSampleTime, newInput.
		IF pidLex:SETPOINT <> oldSetPoint {
			SET oldSetPoint TO pidLex:SETPOINT.
			SET xPID:SETPOINT TO oldSetPoint:X.
			SET yPID:SETPOINT TO oldSetPoint:Y.
			SET zPID:SETPOINT TO oldSetPoint:Z.
		}
		IF ABS(pidLex:MAXOUTPUT) <> oldMaxMag {
			SET oldMaxMag TO ABS(pidLex:MAXOUTPUT).
			SET pidLex:MAXOUTPUT TO oldMaxMag.
			SET xPID:MAXOUTPUT TO oldMaxMag.
			SET yPID:MAXOUTPUT TO oldMaxMag.
			SET zPID:MAXOUTPUT TO oldMaxMag.
			SET xPID:MINOUTPUT TO -oldMaxMag.
			SET yPID:MINOUTPUT TO -oldMaxMag.
			SET zPID:MINOUTPUT TO -oldMaxMag.
		}
		
		LOCAL xVal IS xPID:UPDATE(newSampleTime,newInput:X).
		LOCAL yVal IS yPID:UPDATE(newSampleTime,newInput:Y).
		LOCAL zVal IS zPID:UPDATE(newSampleTime,newInput:Z).
		RETURN v(xVal,yVal,zVal).
	}).
}


