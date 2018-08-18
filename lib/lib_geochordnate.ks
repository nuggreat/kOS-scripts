@LAZYGLOBAL OFF.
LOCAL lib_geochordnate_lex IS LEX().

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

	} ELSE  IF thing:ISTYPE("part") {
		LOCAL thingGeoPos IS SHIP:BODY:GEOPOSITIONOF(thing:POSITION).
		RETURN LEX("chord",thingGeoPos,"name","latlng(" + ROUND(thingGeoPos:LAT,2) + "," + ROUND(thingGeoPos:LNG,2) + ")","type",thing:TYPENAME).

	} ELSE {
		IF doPrint { PRINT "I don't know how use a target type of :" + thing:TYPENAME. }
		RETURN LEX("chord",FALSE,"name",FALSE,"thing",FALSE).
	}
}

FUNCTION str_to_types {//converts a given string to a latlng,waypoint, or vessel
	PARAMETER str,sameBody IS TRUE,doPrint IS TRUE.
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
	LOCAL closest IS thingList[0].
	FOR thing IN thingList {
		LOCAL thingDist IS (thing:POSITION - SHIP:POSITION):MAG.
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

FUNCTION ground_track {	//returns the geocoordinates of the ship at a given time(UTs) adjusting for planetary rotation over time
	PARAMETER pos,posTime.
	LOCAL localBody IS SHIP:BODY.
	LOCAL rotationalDir IS VDOT(localBody:NORTH:FOREVECTOR,localBody:ANGULARVEL). //the number of radians the body will rotate in one second
	LOCAL posLATLNG IS localBody:GEOPOSITIONOF(pos).
	LOCAL timeDif IS posTime - TIME:SECONDS.
	LOCAL longitudeShift IS rotationalDir * timeDif * CONSTANT:RADTODEG.
	LOCAL newLNG IS MOD(posLATLNG:LNG + longitudeShift ,360).
	IF newLNG < - 180 { SET newLNG TO newLNG + 360. }
	IF newLNG > 180 { SET newLNG TO newLNG - 360. }
	RETURN LATLNG(posLATLNG:LAT,newLNG).
}

FUNCTION dist_betwene_coordinates { //returns the dist between p1 and p2 on the localBody, assumes perfect sphere with radius of sea level height
	PARAMETER p1,p2.
	LOCAL localBody IS p1:BODY.
	LOCAL localBodyCirc IS CONSTANT:PI * localBody:RADIUS * 2.
	LOCAL bodyPos IS localBody:POSITION.
	LOCAL bodyToP1Vec IS p1:POSITION - bodyPos.
	LOCAL bodyToP2Vec IS p2:POSITION - bodyPos.
	RETURN VANG(bodyToP1Vec,bodyToP2Vec) / 360 * localBodyCirc.
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
        SET dataLex["maxSamples"] TO maxSamples.
		SET dataLex["sampleCoef"] TO (dataLex["maxSamples"] + 1) / MAX(dataLex["maxSamples"],1).
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