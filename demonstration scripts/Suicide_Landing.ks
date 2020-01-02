LOCAL tarAlt IS 1000.
LOCAL accel IS 0.
LOCAL sign IS 1.
LOCAL tSpeed IS 0.

LOCAL throtPID IS PIDLOOP(0.1,0.01,0.001,0,1).
SET throtPID:SETPOINT TO tSpeed.
LOCK THROTTLE TO throtPID:UPDATE(TIME:SECONDS,SHIP:VERTICALSPEED).
LOCK STEERING TO UP.
LOCAL sufGrav IS SHIP:BODY:MU / BODY:RADIUS^2.

RCS OFF.
UNTIL RCS {
    LOCAL distError IS tarAlt - SHIP:ALTITUDE.
    IF distError > 0 {//below tarAlt
        SET accel TO sufGrav.
        SET sign TO 1.
    } ELSE {//above or at tarAlt
        SET accel TO SHIP:AVAILABLETHRUST / SHIP:MASS - sufGrav.
        SET sign TO -1.
    }
    LOCAL tSpeed IS SQRT(ABS(2 * distError / accel)) * accel * sign.
	SET throtPID:SETPOINT TO tSpeed.
    WAIT 0.
}