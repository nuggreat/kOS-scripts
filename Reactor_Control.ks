IF NOT SHIP:UNPACKED AND SHIP:LOADED { PRINT "waiting for unpack". WAIT UNTIL SHIP:UNPACKED AND SHIP:LOADED. WAIT 1. PRINT "unpacked". }
SET CORE:PART:TAG TO "reactor_controler".
WAIT 1.
//PID setup PIDLOOP(kP,kI,kD,min,max)
LOCAL reactorPID IS PIDLOOP(100,0,100,-100,100).

SET reactorPID:SETPOINT TO 0.9.
LOCAL reactorControlers IS SHIP:PARTSTAGGED("reactor_controler").
LOCAL isControlCore IS am_control_core(reactorControlers).
LOCAL reactorModuleList IS SHIP:MODULESNAMED("FissionReactor").
LOCAL ec IS get_ec().

ON SHIP:PARTS:LENGTH {//detection of docking events
	SET ec TO get_ec().
	SET numberOfParts TO SHIP:PARTS:LENGTH.
	SET newScanTime TO TIME:SECONDS - 1.
	PRESERVE.
}

LOCAL newScanTime IS TIME:SECONDS + 10.
WHEN TIME:SECONDS > newScanTime THEN {
	SET newScanTime TO newScanTime + (RANDOM() * 9 + 1).
	LOCAL localReactorControlers IS SHIP:PARTSTAGGED("reactor_controler").
	IF reactorControlers <> localReactorControlers {
		SET reactorControlers TO localReactorControlers.
		SET isControlCore TO am_control_core(reactorControlers).
		SET reactorModuleList TO SHIP:MODULESNAMED("FissionReactor").
	}
	PRESERVE.
}

IF isControlCore {
	PRINT "have control".
}

UNTIL FALSE {
	IF isControlCore {
		IF not_warping() {
			LOCAL ecPrecentage IS ec:AMOUNT / ec:CAPACITY.
			LOCAL settingChange IS reactorPID:UPDATE(TIME:SECONDS,ecPrecentage).
			FOR reactor IN reactorModuleList {
				LOCAL coreSetting IS MIN(MAX(reactor:GETFIELD("power setting") + settingChange,reactor:PART:TAG:TONUMBER(0)),100).
				reactor:SETFIELD("power setting",coreSetting).
			}
			WAIT 0.
		} ELSE {
			WAIT UNTIL not_warping().
		}
	} ELSE {
		PRINT "no control".
		WAIT UNTIL isControlCore.
		PRINT "have control".
	}
}

FUNCTION get_ec {
	FOR res IN SHIP:RESOURCES {
		IF res:NAME = "electricCharge" {
			RETURN res.
		}
	}
}

FUNCTION am_control_core {
	PARAMETER controlerList IS SHIP:PARTSTAGGED("reactor_controler").
	LOCAL coreNumber IS (CORE:PART:UID + ".0"):TONUMBER().
	LOCAL isControlCore IS TRUE.
	FOR controler IN controlerList {
		IF (controler:UID + ".0"):TONUMBER() > coreNumber {
			RETURN FALSE.
		}
	}
	RETURN TRUE.
}

FUNCTION not_warping {
	RETURN (KUNIVERSE:TIMEWARP:RATE = 1) AND KUNIVERSE:TIMEWARP:ISSETTLED.
}