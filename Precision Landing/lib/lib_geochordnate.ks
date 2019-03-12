@LAZYGLOBAL OFF.
LOCAL lib_geochordnate_lex IS LEX().
PRINT "libGeo Loaded".

FUNCTION mis_types_to_geochordnate {	//converts types of vessel,part,waypoint, and string into geocoordinates
	PARAMETER thing,doPrint IS TRUE.
	IF thing:ISTYPE("string") {
		SET thing TO str_to_types(thing,TRUE,doPrint).
	}

	IF thing:ISTYPE("geocoordinates") {
		RETURN LEX("chord",thing,"name","latlng(" + ROUND(thing:LAT,2) + "," + ROUND(thing:LNG,2) + ")","type","geocoordinates").

	} ELSE IF thing:ISTYPE("waypoint") OR thing:ISTYPE("vessel") {
		RETURN LEX("chord",thing:GEOPOSITION,"name",thing:NAME,"type",thing:TYPENAME).

	} ELSE IF thing:ISTYPE("vector") {
		LOCAL thingGeoPos IS SHIP:BODY:GEOPOSITIONOF(thing).
		RETURN LEX("chord",thingGeoPos,"name","latlng(" + ROUND(thingGeoPos:LAT,2) + "," + ROUND(thingGeoPos:LNG,2) + ")","type","position").

	} ELSE IF thing:ISTYPE("part") {
		IF thing:SHIP:BODY = SHIP:BODY {
			LOCAL thingGeoPos IS SHIP:BODY:GEOPOSITIONOF(thing:POSITION).
			RETURN LEX("chord",thingGeoPos,"name","latlng(" + ROUND(thingGeoPos:LAT,2) + "," + ROUND(thingGeoPos:LNG,2) + ")","type",thing:TYPENAME).
		} ELSE {
			IF doPrint { PRINT thing + " is not on the same body". }
			RETURN LEX("chord",FALSE,"name",FALSE,"thing",FALSE).
		}

	}
	IF doPrint { PRINT "I don't know how use a target type of :" + thing:TYPENAME. }
	RETURN LEX("chord",FALSE,"name",FALSE,"thing",FALSE).
}

FUNCTION str_to_types {//converts a given string to a latlng,waypoint, or vessel
	PARAMETER str,sameBody IS TRUE,doPrint IS TRUE,doLatLng IS TRUE,doWaypoint IS TRUE,doCraft IS TRUE.
	IF str:ISTYPE("string") {				//string should only include one "," this is for separating the latlng numbers like: "-10,45" is valid
		LOCAL strSplit IS str:SPLIT(",").	//the "," can also separate the parts of a waypoint/craft name
		IF strSplit:LENGTH > 1 {				//EXAMPLE "mun,lander" is valid for craft with names: "munlander", "mun station lander", "lander mun-station"
			LOCAL latVal IS strSplit[0]:TONUMBER(-1000).
			LOCAL lngVal IS strSplit[1]:TONUMBER(-1000).
			IF (latVal <> -1000) AND (lngVal <> -1000) {
				RETURN LATLNG(latVal,lngVal).
			}
		}

		LOCAL candidateList IS LIST().
		FOR point IN ALLWAYPOINTS() {
			IF (NOT sameBody) OR (point:BODY = SHIP:BODY) {
				IF contains_srt_list(point,strSplit) {
					candidateList:ADD(point).
				}
			}
		}
		IF candidateList:LENGTH > 0 {
			RETURN closest_thing(candidateList).
		}

		LOCAL vesselList IS LIST().
		LIST TARGETS IN vesselList.
		FOR ves IN vesselList {
			IF (NOT sameBody) OR ((ves:BODY = SHIP:BODY) AND (ves:STATUS = "Landed")) {
				IF contains_srt_list(ves,strSplit) {
					candidateList:ADD(ves).
				}
			}
		}
		IF candidateList:LENGTH > 0 {
			RETURN closest_thing(candidateList).
		}

		IF doPrint { PRINT "unable to find a valid target for string: " + str. }
		RETURN str.

	} ELSE {
		IF doPrint {  PRINT "type was not a string". }
		RETURN FALSE.
	}
}

LOCAL FUNCTION closest_thing {//returns the thing closest to the ship
	PARAMETER thingList.
	LOCAL dist IS (thingList[0]:POSITION - SHIP:POSITION):MAG.
	//LOCAL dist IS thingList[0]:DISTANCE.
	LOCAL closest IS thingList[0].
	FOR thing IN thingList {
		LOCAL thingDist IS (thing:POSITION - SHIP:POSITION):MAG.
		//LOCAL thingDist IS thingList[0]:DISTANCE.
		IF thingDist < dist {
			SET dist to thingDist.
			SET closest TO thing.
		}
	}
	RETURN closest.
}

LOCAL FUNCTION contains_srt_list { //checks if the name of a thing contains the strings of the passed in list
	PARAMETER thing,srtList.
	LOCAL validThing IS TRUE.
	FOR srtPart IN srtList {
		IF NOT thing:NAME:CONTAINS(srtPart) {
			SET validThing TO FALSE.
			BREAK.
		}
	}
	RETURN validThing.
}

FUNCTION ground_track {	//returns the geocoordinates of the ship at a given time(UTs) adjusting for planetary rotation over time, only works for non tilted spin on bodies 
	PARAMETER pos,posTime,localBody IS SHIP:BODY.
	LOCAL bodyNorth IS v(0,1,0).//using this instead of localBody:NORTH:VECTOR because in many cases the non hard coded value is incorrect
	LOCAL rotationalDir IS VDOT(bodyNorth,localBody:ANGULARVEL) * CONSTANT:RADTODEG. //the number of degrees the body will rotate in one second
	LOCAL posLATLNG IS localBody:GEOPOSITIONOF(pos).
	LOCAL timeDif IS posTime - TIME:SECONDS.
	LOCAL longitudeShift IS rotationalDir * timeDif.
	LOCAL newLNG IS MOD(posLATLNG:LNG + longitudeShift,360).
	IF newLNG < - 180 { SET newLNG TO newLNG + 360. }
	IF newLNG > 180 { SET newLNG TO newLNG - 360. }
	RETURN LATLNG(posLATLNG:LAT,newLNG).
}

FUNCTION dist_between_coordinates { //returns the dist between p1 and p2 on the localBody, assumes perfect sphere with radius of the body + what ever gets passed in to atAlt
	PARAMETER p1,p2,atAlt IS 0.
	LOCAL localBody IS p1:BODY.
	LOCAL localBodyCirc IS CONSTANT:PI * (localBody:RADIUS + atAlt).//half the circumference of body
	LOCAL bodyPos IS localBody:POSITION.
	LOCAL bodyToP1Vec IS p1:POSITION - bodyPos.
	LOCAL bodyToP2Vec IS p2:POSITION - bodyPos.
	RETURN VANG(bodyToP1Vec,bodyToP2Vec) / 180 * localBodyCirc.
}

FUNCTION inital_heading { //returns the initial heading for shortest distance between p1 and p2 going from p1 to p2
	PARAMETER p1,p2.
	LOCAL lngDif IS p2:LNG - p1:LNG.
	LOCAL cosP2lat IS COS(p2:LAT).
	RETURN MOD(360 + ARCTAN2(SIN(lngDif) * cosP2lat,COS(p1:LAT) * SIN(p2:LAT) - SIN(p1:LAT) * cosP2lat * COS(lngDif)), 360).
}

FUNCTION distance_heading_to_latlng {//takes in a heading, distance, and start point and returns the latlng at the end of the greater circle
	PARAMETER head,dist,p1 IS SHIP:GEOPOSITION.
	LOCAL localBody IS p1:BODY.
	LOCAL degTravle IS (dist*180) / (p1:BODY:RADIUS * CONSTANT:PI).//degrees around the body, might make as constant
	LOCAL sinP1lat IS SIN(p1:LAT).
	LOCAL sinDegTcosP1lat IS SIN(degTravle)*COS(p1:LAT).
	LOCAL newLat IS ARCSIN(sinP1lat*COS(degTravle) + sinDegTcosP1lat*COS(head)).
	IF ABS(newLat) <> 90 {
		LOCAL newLng IS p1:LNG + ARCTAN2(SIN(head)*sinDegTcosP1lat,COS(degTravle)-sinP1lat*SIN(newLat)).
		RETURN LATLNG(newLat,newLng).
	} ELSE {
		RETURN LATLNG(newLat,0).
	}
}

FUNCTION slope_calculation {//returns the slope of p1 in degrees
	PARAMETER p1.
	LOCAL upVec IS (p1:POSITION - p1:BODY:POSITION):NORMALIZED.
	RETURN VANG(upVec,surface_normal(p1)).
}

FUNCTION surface_normal {
	PARAMETER p1.
	LOCAL localBody IS p1:BODY.
	LOCAL basePos IS p1:POSITION.

	LOCAL upVec IS (basePos - localBody:POSITION):NORMALIZED.
	LOCAL northVec IS VXCL(upVec,LATLNG(90,0):POSITION - basePos):NORMALIZED * 4.
	LOCAL sideVec IS VCRS(upVec,northVec):NORMALIZED * 3.//is east

	LOCAL aPos IS localBody:GEOPOSITIONOF(basePos - northVec + sideVec):POSITION - basePos.
	LOCAL bPos IS localBody:GEOPOSITIONOF(basePos - northVec - sideVec):POSITION - basePos.
	LOCAL cPos IS localBody:GEOPOSITIONOF(basePos + northVec):POSITION - basePos.
	RETURN VCRS((aPos - cPos),(bPos - cPos)):NORMALIZED.
}

FUNCTION grade_claculation {//returns the grade traveling from p1 to p2, positive is up hill, negative is down hill
	PARAMETER p1,p2.
	LOCAL dist IS dist_between_coordinates(p1,p2).
	IF dist <> 0 {
		RETURN ARCTAN((p1:TERRAINHEIGHT - p2:TERRAINHEIGHT) / dist).
	} ELSE {
		RETURN 0.
	}
}

lib_geochordnate_lex:ADD("targetETAdata",LEX("oldDist",1,"averageDeltaDist",0,"oldTime",TIME:SECONDS,"firstSample",TRUE,"sampleCoef",(21 / 20),"maxSamples",20)).
FUNCTION average_eta {
    LOCAL dataLex IS lib_geochordnate_lex["targetETAdata"].
    PARAMETER dist,maxSamples IS dataLex["maxSamples"],resetData IS FALSE.
    LOCAL localTime IS TIME:SECONDS.
    IF resetData {
        SET dataLex["oldDist"] TO dist.
        SET dataLex["oldTime"] TO localTime.
        SET dataLex["averageDeltaDist"] TO 0.
        SET dataLex["firstSample"] TO TRUE.
        SET dataLex["maxSamples"] TO MAX(maxSamples,1).
		SET dataLex["sampleCoef"] TO (dataLex["maxSamples"] + 1) / dataLex["maxSamples"].
        RETURN 0.
    } ELSE {
        LOCAL deltaTime IS localTime - dataLex["oldTime"].
        SET dataLex["oldTime"] TO localTime.
        LOCAL deltaDist IS (dataLex["oldDist"] - dist) / deltaTime.
		IF dataLex["firstSample"] {
			SET deltaDist TO deltaDist * (dataLex["maxSamples"] + 1).
			SET dataLex["firstSample"] TO FALSE.
		}
        SET dataLex["oldDist"] TO dist.
        SET dataLex["averageDeltaDist"] TO (dataLex["averageDeltaDist"] + deltaDist) / (dataLex["sampleCoef"]).
        RETURN dist / (dataLex["averageDeltaDist"] / dataLex["maxSamples"]).
    }
}