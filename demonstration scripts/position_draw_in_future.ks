RCS OFF.
LOCAL t IS TIME:SECONDS.
LOCAL shipToFutureShip IS VECDRAW(SHIP:POSITION,solar_relitave_positionAt(IKE,t),BLUE,"future ike is here",1,TRUE,0.2).
LOCAL shipToFutureKerbin IS VECDRAW(SHIP:POSITION,solar_relitave_positionAt(DUNA,t),GREEN,"future Duna is here",1,TRUE,0.2).
UNTIL RCS {
  WAIT 0.
  SET t TO t + 10.
  SET shipToFutureShip:START TO SHIP:POSITION.
  SET shipToFutureShip:VEC TO solar_relitave_positionAt(IKE,t).
  SET shipToFutureKerbin:START TO SHIP:POSITION.
  SET shipToFutureKerbin:VEC TO solar_relitave_positionAt(DUNA,t).
}
CLEARVECDRAWS().

FUNCTION solar_relitave_positionAt {
  PARAMETER orbital,t,firstRun IS TRUE.
  //IF firstRun {
  //  RETURN POSITIONAT(orbital,t) + solar_relitave_positionAt(orbital:BODY,t,FALSE).
  //} ELSE {
    IF orbital:HASBODY {
      RETURN (POSITIONAT(orbital,t) - orbital:BODY:POSITION) + solar_relitave_positionAt(orbital:BODY,t,FALSE).
      //RETURN (POSITIONAT(orbital,t) - orbital:POSITION) + solar_relitave_positionAt(orbital:BODY,t,FALSE).
    } ELSE {
      //RETURN v(0,0,0).
      RETURN orbital:POSITION.
    }
  //}
}