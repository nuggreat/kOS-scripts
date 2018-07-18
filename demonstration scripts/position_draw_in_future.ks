RCS OFF.
LOCAL t IS TIME:SECONDS.
LOCAL shipToFutureShip IS VECDRAW(SHIP:POSITION,solar_relitave_positionAt(SHIP,t),BLUE,"future ship is here",1,TRUE,0.2).
LOCAL shipToFutureKerbin IS VECDRAW(SHIP:POSITION,solar_relitave_positionAt(KERBIN,t),GREEN,"future kerbin is here",1,TRUE,0.2).
UNTIL RCS {
  WAIT 0.
  SET t TO t + 10.
  SET shipToFutureShip:START TO SHIP:POSITION.
  SET shipToFutureShip:VEC TO solar_relitave_positionAt(SHIP,t).
  SET shipToFutureKerbin:START TO SHIP:POSITION.
  SET shipToFutureKerbin:VEC TO solar_relitave_positionAt(KERBIN,t).
}
CLEARVECDRAWS().

FUNCTION solar_relitave_positionAt {
  PARAMETER orbital,t,firstRun IS TRUE.
  IF firstRun {
    RETURN POSITIONAT(orbital,t) + solar_motion(orbital:BODY,t,FALSE).
  } ELSE {
    IF orbital = SUN {
      RETURN v(0,0,0).
    } ELSE {
      RETURN (POSITIONAT(orbital,t) - orbital:POSITION) + solar_motion(orbital:BODY,t,FALSE).
    }
  }
}