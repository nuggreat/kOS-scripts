RCS OFF.
LOCAL t IS TIME:SECONDS.
LOCAL shipToFutureShip IS VECDRAW(SHIP:POSITION,POSITIONAT(SHIP,t),BLUE,"future ship is here",1,TRUE,0.2).
LOCAL shipToFuturekerbin IS VECDRAW(SHIP:POSITION,POSITIONAT(KERBIN,t),BLUE,"future kerbin is here",1,TRUE,0.2).
UNTIL RCS {
  WAIT 0.
  SET t TO t + 10.
  SET shipToFutureShip:START TO SHIP:POSITION.
  SET shipToFutureShip:VEC TO POSITIONAT(SHIP,t).
  SET shipToFuturekerbin:START TO SHIP:POSITION.
  SET shipToFuturekerbin:VEC TO POSITIONAT(KERBIN,t).
}
CLEARVECDRAWS().