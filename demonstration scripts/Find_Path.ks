PARAMETER dist IS 10000, head IS  0.
copypath("0:/Rover_path.ks","1:/").
copypath("0:/Rover_path_v3.ks","1:/").
// copypath("0:/lib/lib_geochordnate.ks","1:/lib/").
IF head < 0 { SET head TO (-head) * 360. }
LOCAL startTime IS TIME:SECONDS.
run rover_path_v3(distance_heading_to_latlng(head,dist)).
PRINT TIME:SECONDS - startTime.

FUNCTION distance_heading_to_latlng {//takes in a heading, distance, and start point and returns the latlng at the end of the greater circle
    PARAMETER head,dist,p1 IS SHIP:GEOPOSITION.
    LOCAL localBody IS p1:BODY.
    LOCAL degTravle IS (dist*180) / (p1:BODY:RADIUS * CONSTANT:PI).//degrees around the body, might make as constant
    LOCAL newLat IS ARCSIN(SIN(p1:LAT)*COS(degTravle) + COS(p1:LAT)*SIN(degTravle)*COS(head)).
    IF newLat <> 90 {
        LOCAL newLng IS p1:LNG + ARCTAN2(SIN(head)*SIN(degTravle)*COS(p1:LAT),COS(degTravle)-SIN(p1:LAT)*SIN(newLat)).
        RETURN LATLNG(newLat,newLng).
    } ELSE {
        RETURN LATLNG(newLat,0).
    }
}