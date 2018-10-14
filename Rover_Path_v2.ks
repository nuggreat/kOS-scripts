//TODO: try adding a smothing function
//TODO: adjust lastwaypoint to be exactly at edge of closeToDist
//TODO: add pathDist to score

FOR lib IN LIST("lib_geochordnate") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
PARAMETER endPoint,closeToDist IS 450,waypointRadius IS 10.
CLEARSCREEN.
LOCAL varConstants IS LEX().
LOCAL nodeTree IS LEX().
LOCAL nodeQue IS LIST().

LOCAL destData IS mis_types_to_geochordnate(endPoint).
LOCAL dest IS destData["chord"].
LOCAL destName IS destData["name"].
LOCAL doRoving IS FALSE.
IF dest:ISTYPE("geocoordinates") { SET doRoving TO TRUE.}

IF doRoving {

LOCAL initalDist IS dist_between_coordinates(dest,SHIP:GEOPOSITION).
//LOCAL unitDist IS initalDist / 5^CEILING(LN(initalDist / MIN(100,(closeToDist / 2))) / LN(5)).
LOCAL unitDist IS MIN(100,(closeToDist)).
SET varConstants TO LEX(
	//"unitDist",unitDist,
	"maxDist",(unitDist),
	"unitDistDeg",(unitDist*180) / (SHIP:BODY:RADIUS * CONSTANT:PI),
	"dest",dest,
	"northRef",distance_heading_to_latlng(deg_protect(dest:HEADING + 90),SHIP:BODY:RADIUS / 2 * CONSTANT:PI,SHIP:GEOPOSITION),
	//"nodeCluster",LIST(LIST(0,2,TRUE,LIST(1,5)),
	//				   LIST(1,1,FALSE),
	//				   LIST(1,-1,TRUE,LIST(1,3)),
	//				   LIST(0,-2,FALSE),
	//				   LIST(-1,-1,TRUE,LIST(3,5)),
	//				   LIST(-1,1,FALSE))
					   
	"nodeCluster",LIST(LIST(0,2,TRUE,LIST(0,1)),
					   LIST(1,1,TRUE,LIST(1,2)),
					   LIST(1,-1,TRUE,LIST(2,3)),
					   LIST(0,-2,TRUE,LIST(3,4)),
					   LIST(-1,-1,TRUE,LIST(4,5)),
					   LIST(-1,1,TRUE,LIST(5,0)))
	).

LOCAL starNodeChord IS SHIP:GEOPOSITION.
nodeTree:ADD("0,0",LEX("latLng",starNodeChord)).
LOCAL localNode IS nodeTree["0,0"].
localNode:ADD("distToDest",dist_between_coordinates(starNodeChord,varConstants["dest"])).
localNode:ADD("alt",starNodeChord:TERRAINHEIGHT).
localNode:ADD("slope",slope_calculation(starNodeChord)).
localNode:ADD("preNewVec",V(0,0,0)).
localNode:ADD("preDist",0).
localNode:ADD("totalDist",0).
localNode:ADD("prevousNodeID","0,0").
localNode:ADD("totalScore",0).
localNode:ADD("nodeScore",0).
nodeQue:ADD(LIST("0,0",0)).

LOCAL waypointList IS LIST().
LOCAL startDist IS localNode["distToDest"].
LOCAL closestDist IS startDist - 0.01.
PRINT "   closest Dist: " + ROUND(closestDist) AT(0,3).
LOCAL bestVec IS VECDRAW(SHIP:POSITION,SHIP:UP:VECTOR * 200, GREEN,"",1,TRUE,10).
LOCAL done IS FALSE.
LOCAL startTime IS TIME:SECONDS.
UNTIL done {
	LOCAL nodeID IS nodeQue[0][0].
	LOCAL storedScore IS nodeQue[0][1].
	nodeQue:REMOVE(0).
	LOCAL nodeDist IS nodeTree[nodeID]["distToDest"].
	IF nodeDist < closeToDist {
		IF back_propogation_check(nodeID) {
			SET done TO TRUE.
			SET waypointList TO back_propogation_waypoint_list(nodeID).
		} ELSE {
			SET closestDist TO startDist - 0.01.
		}
	} ELSE {
		IF ABS(storedScore - nodeTree[nodeID]["totalScore"]) < 0.01 {
			evaluate_node_cluster(nodeID).
		}
	}
	IF nodeDist < closestDist {
		SET closestDist TO ROUND(nodeDist).
		LOCAL pointPos IS nodeTree[nodeID]["latLng"]:POSITION.
		SET bestVec:START TO pointPos.
		SET bestVec:VEC TO (pointPos - SHIP:BODY:POSITION):NORMALIZED * 200.
		PRINT "   closest Dist: " + closestDist + "      " AT(0,3).
		PRINT " Time Remaining: " + ROUND(closestDist / ((startDist - closestDist) / (TIME:SECONDS - startTime))) + "    " AT(0,4).
	}
	PRINT "number of Nodes: " + nodeQue:LENGTH + "      " AT(0,2).
}
PRINT "elapsed time: " + ROUND(TIME:SECONDS - startTime) AT(0,6).
PRINT "tree size: " + nodeTree:LENGTH AT(0,7).
PRINT "path size: " + waypointList:LENGTH AT(0,8).

LOCAL renderedVectors IS LIST().
LOCAL prevousPoint IS SHIP:GEOPOSITION.
FOR point IN waypointList {
	LOCAL pointPos IS point:POSITION.
	LOCAL adjustPos IS pointPos + ((pointPos - SHIP:BODY:POSITION):NORMALIZED * 20).
	LOCAL prePos IS prevousPoint:POSITION.
	LOCAL adjPrePos IS prePos + ((prePos - SHIP:BODY:POSITION):NORMALIZED * 20).
	renderedVectors:ADD(VECDRAW(adjPrePos,(adjustPos - adjPrePos),green,"",1,TRUE,10)).
	SET prevousPoint TO point.
}
RCS OFF.
WAIT UNTIL RCS.
CLEARVECDRAWS().

}

FUNCTION back_propogation_check {
	PARAMETER initalNodeID,errorRange IS 1.
	LOCAL nodeID IS initalNodeID.
	LOCAL endScore IS nodeTree[nodeID]["totalScore"].
	LOCAL recalcedScore IS nodeTree[nodeID]["nodeScore"].
	LOCAL done IS FALSE.
	UNTIL nodeID = "0,0" {
		SET nodeID TO nodeTree[nodeID]["prevousNodeID"].
		SET recalcedScore TO recalcedScore + nodeTree[nodeID]["nodeScore"].
	}
	LOCAL scoreError IS endScore - recalcedScore.
	PRINT "scoreError: " + ROUND(scoreError,2) + "      " AT(0,5).
	RETURN ABS(scoreError) < errorRange.
}

FUNCTION back_propogation_waypoint_list {
	PARAMETER initalNodeID.
	LOCAL nodeID IS initalNodeID.
	LOCAL returnList IS LIST(nodeTree[nodeID]["latLng"]).
	LOCAL done IS FALSE.
	UNTIL nodeID = "0,0" {
		SET nodeID TO nodeTree[nodeID]["prevousNodeID"].
		returnList:INSERT(0,nodeTree[nodeID]["latLng"]).
	}
	RETURN returnList.
}

FUNCTION nullFunc {
	//the node stored for any given nodeID is
	LOCAL nullNodeLex IS LEX(
	"latLng",someVal,
	"distToDest",someVal,
	"alt",someVal,
	"slope",someVal,
	"preNewVec",someVal,
	"prevousNodeID",someVal,
	"nodeScore",someVal,
	"totalScore",someVal).
}

FUNCTION evaluate_node_cluster {
	PARAMETER preNodeID.
	LOCAL nodeID IS preNodeID:SPLIT(",").
	//LOCAL subNodes IS LIST().
	FOR point IN varConstants["nodeCluster"] {
		LOCAL newNodeID IS newID(nodeID,point).
		//IF point[2] {
		//	subNodes:ADD(LIST(newNodeID[0],point[3])).
		//}
		IF evaluate_node(preNodeID,preNodeID,newNodeID[0],newNodeID[1]) {
			add_node_to_que(newNodeID[0]).
		}
	}
	//FOR subNode IN subNodes {
	//	SET nodeID TO subNode[0]:SPLIT(",").
	//	FOR newPoint IN subNode[1] {
	//	//FOR newPoint IN LIST(0,1,2,3,4,5) {
	//		LOCAL newNodeID IS newID(nodeID,varConstants["nodeCluster"][newPoint]).
	//		IF evaluate_node(preNodeID,subNode[0],newNodeID[0],newNodeID[1]) {
	//			add_node_to_que(newNodeID[0]).
	//		}
	//	}
	//}
}

FUNCTION newID {
	PARAMETER xyVal,changeList.
	LOCAL xVal IS xyVal[0]:TONUMBER() + changeList[0].
	LOCAL yVal IS xyVal[1]:TONUMBER() + changeList[1].
	RETURN LIST(xVal + "," + yVal,LIST(xVal,yVal)).
}

FUNCTION add_node_to_que {
	PARAMETER nodeID.
	LOCAL queLength IS nodeQue:LENGTH.
	IF queLength = 0 {
		nodeQue:ADD(LIST(nodeID,nodeTree[nodeID]["totalScore"])).
	} ELSE {
		LOCAL nodeScore IS nodeTree[nodeID]["totalScore"].
		LOCAL queIncrement IS MAX(FLOOR(queLength / 2),1).
		LOCAL queIndex IS MAX(queIncrement - 1,0).
		LOCAL divCounter IS FLOOR(LN(queLength) / LN(2)).
		UNTIL FALSE {
			IF divCounter > 0 {
				SET divCounter TO divCounter - 1.
				SET queIncrement TO MAX(FLOOR(queIncrement/2),1).
				IF nodeTree[nodeQue[ROUND(queIndex)][0]]["totalScore"] < nodeScore {
					SET queIndex TO MIN(queIndex + queIncrement,queLength).
				} ELSE {
					SET queIndex TO MAX(queIndex - queIncrement,0).
				}
				IF divCounter <= 0 {
					SET queIndex TO ROUND(queIndex).
				}
			} ELSE {
				IF nodeTree[nodeQue[queIndex][0]]["totalScore"] < nodeScore {
					SET queIndex TO MIN(queIndex + 1,queLength).
					IF (queIndex >= queLength) OR (nodeTree[nodeQue[queIndex][0]]["totalScore"] >= nodeScore) {
						nodeQue:INSERT(queIndex,LIST(nodeID,nodeTree[nodeID]["totalScore"])).
						BREAK.
					}
				} ELSE {
					IF queIndex <= 0 {
						nodeQue:INSERT(queIndex,LIST(nodeID,nodeTree[nodeID]["totalScore"])).
						BREAK.
					}
					SET queIndex TO MAX(queIndex - 1,0).
				}
			}
		}
	}
}

FUNCTION evaluate_node {
	PARAMETER preNodeID,centerNodeID,newNodeIDstr,newNodeIDnum.
	LOCAL preNode IS nodeTree[preNodeID].
	LOCAL isBetter IS FALSE.
	IF nodeTree:HASKEY(newNodeIDstr) {
		LOCAL localNode IS nodeTree[newNodeIDstr].
		LOCAL oldTotalScore IS localNode["totalScore"].
		LOCAL newNodeScore IS node_score(preNodeID,newNodeIDstr).
		LOCAL newTotalScore IS preNode["totalScore"] + newNodeScore.
		IF newTotalScore < oldTotalScore {
			//remove_from_que(newNodeIDstr,oldTotalScore).
			LOCAL preNodeChord IS preNode["latLng"].
			SET localNode["preNewVec"] TO localNode["latLng"]:POSITION - preNodeChord:POSITION.
			SET localNode["preDist"] TO dist_between_coordinates(preNodeChord,localNode["latLng"]).
			SET localNode["totalDist"] TO localNode["preDist"] + preNode["totalDist"].
			SET localNode["prevousNodeID"] TO preNodeID.
			SET localNode["nodeScore"] TO newNodeScore.
			SET localNode["totalScore"] TO newTotalScore.
			SET isBetter TO TRUE.
		}
	} ELSE {
		LOCAL center IS centerNodeID:SPLIT(",").
		LOCAL northHeading IS inital_heading(nodeTree[centerNodeID]["latLng"],varConstants["northRef"]).
		LOCAL newNodeHead IS 0.
		LOCAL xVal IS center[0]:TONUMBER() - newNodeIDnum[0].
		LOCAL yVal IS center[1]:TONUMBER() - newNodeIDnum[1].
		IF xVal = 0 {
			IF yVal > 0 {
				SET newNodeHead TO northHeading - 90.//0
			} ELSE {
				SET newNodeHead TO northHeading + 90.//180
			}
		} ELSE IF xVal > 0 {
			IF yVal > 0 {
				SET newNodeHead TO northHeading - 30.//60
			} ELSE {
				SET newNodeHead TO northHeading + 210.//300
			}
		} ELSE {
			IF yVal > 0 {
				SET newNodeHead TO northHeading + 30.//120
			} ELSE {
				SET newNodeHead TO northHeading + 150.//240
			}
		}
		LOCAL newNodeChord IS new_node_chord(deg_protect(newNodeHead),nodeTree[centerNodeID]["latLng"]).
		nodeTree:ADD(newNodeIDstr,LEX("latLng",newNodeChord)).
		LOCAL localNode IS nodeTree[newNodeIDstr].
		LOCAL preNodeChord IS preNode["latLng"].
		localNode:ADD("distToDest",dist_between_coordinates(newNodeChord,varConstants["dest"])).
		localNode:ADD("alt",newNodeChord:TERRAINHEIGHT).
		localNode:ADD("slope",slope_calculation(newNodeChord)).
		localNode:ADD("preNewVec",newNodeChord:POSITION - preNodeChord:POSITION).
		localNode:ADD("preDist",dist_between_coordinates(preNodeChord,newNodeChord)).
		localNode:ADD("totalDist",localNode["preDist"] + preNode["totalDist"]).
		localNode:ADD("prevousNodeID",preNodeID).
		localNode:ADD("nodeScore",node_score(preNodeID,newNodeIDstr)).
		localNode:ADD("totalScore",preNode["totalScore"] + localNode["nodeScore"]).
		SET isBetter TO TRUE.
	}
	RETURN isBetter.
}

FUNCTION remove_from_que {
	PARAMETER nodeID,nodeScore.
	IF nodeQue:CONTAINS(nodeID) {
		LOCAL queLength IS nodeQue:LENGTH.
		LOCAL queIncrement IS MAX(FLOOR(queLength / 2),1).
		LOCAL queIndex IS MAX(queIncrement - 1,0).
		LOCAL divCounter IS FLOOR(LN(queLength) / LN(2)).
		LOCAL queHighScan IS queIndex.
		LOCAL queLowScan IS queIndex.
		UNTIL FALSE {
			IF divCounter > 0 {
				SET divCounter TO divCounter - 1.
				SET queIncrement TO MAX(FLOOR(queIncrement/2),1).
				IF nodeTree[nodeQue[ROUND(queIndex)]]["totalScore"] < nodeScore {
					SET queIndex TO MIN(queIndex + queIncrement,queLength).
				} ELSE {
					SET queIndex TO MAX(queIndex - queIncrement,0).
				}
				IF divCounter <= 0 {
					SET queHighScan TO ROUND(queIndex).
					IF nodeQue[queHighScan] = nodeID {
						nodeQue:REMOVE(queHighScan).
						BREAK.
					}
					SET queLowScan TO queHighScan.
				}
			} ELSE {
				IF queHighScan < queLength {
					//PRINT "checking high: " + nodeQue[queHighScan] AT(0,6).
					IF nodeQue[queHighScan] = nodeID {
					
						nodeQue:REMOVE(queHighScan).
						BREAK.
					} ELSE {
						SET queHighScan TO queHighScan + 1.
					}
				}
				IF queLowScan >= 0 {
					//PRINT "checking low: " + nodeQue[queHighScan] AT(0,7).
					IF nodeQue[queLowScan] = nodeID {
						nodeQue:REMOVE(queLowScan).
						BREAK.
					} ELSE {
						SET queLowScan TO queLowScan - 1.
					}
				}
			}
		}
	}
}

FUNCTION slope_calculation {
	PARAMETER p1.
	LOCAL localBody IS p1:BODY.
	LOCAL basePos IS p1:POSITION.
	
	LOCAL upVec IS (basePos - localBody:POSITION):NORMALIZED.
	LOCAL northVec IS VXCL(upVec,LATLNG(90,0):POSITION - basePos):NORMALIZED * 4.
	LOCAL sideVec IS VCRS(upVec,northVec):NORMALIZED * 3.//is east
	
	LOCAL aPos IS localBody:GEOPOSITIONOF(basePos - northVec + sideVec):POSITION - basePos.
	LOCAL bPos IS localBody:GEOPOSITIONOF(basePos - northVec - sideVec):POSITION - basePos.
	LOCAL cPos IS localBody:GEOPOSITIONOF(basePos + northVec):POSITION - basePos.
	LOCAL p1Normal IS VCRS((aPos - cPos),(bPos - cPos)).
	RETURN VANG(upVec,p1Normal).
}

FUNCTION node_score {
	PARAMETER preNodeID,newNodeID.
	LOCAL preNode IS nodeTree[preNodeID].
	LOCAL newNode IS nodeTree[newNodeID].
	LOCAL nodeDist IS dist_between_coordinates(preNode["latLng"],newNode["latLng"]) + 0.000001.
	LOCAL score IS (ARCTAN(ABS(preNode["alt"] - newNode["alt"]) / nodeDist)^1.25).//may need to add a div0 protect
	//LOCAL score IS SIN(ARCTAN(ABS(preNode["alt"] - newNode["alt"]) / nodeDist)) * 10.//may need to add a div0 protect
	//PRINT "altAng: " + score + "      " AT(0,9).
	SET score TO score + newNode["slope"]^1.1.
	//SET score TO score + SIN(newNode["slope"]).
	//SET score TO score + signed_exponent(newNode["distToDest"] - preNode["distToDest"],0.75).//negative when going towards dest
	//SET score TO score + (newNode["distToDest"] - preNode["distToDest"]) / varConstants["maxDist"].//negative when going towards dest
	SET score TO score + (newNode["distToDest"] - preNode["distToDest"]).//negative when going towards dest
	SET score TO score + newNode["preDist"].
	//SET score TO score + signed_exponent(newNode["distToDest"] - preNode["distToDest"] + varConstants["maxDist"],0.75).//negative when going towards dest
	//SET score TO score + newNode["distToDest"] - preNode["distToDest"] + varConstants["maxDist"].//negative when going towards dest
	SET score TO score + (VANG(newNode["latLng"]:POSITION - preNode["latLng"]:POSITION,preNode["preNewVec"])^0.5).//a measure of turn angle
	//SET score TO score + SIN(VANG(newNode["latLng"]:POSITION - preNode["latLng"]:POSITION,preNode["preNewVec"]) / 2).//a measure of turn angle
	//PRINT "slope: " + newNode["slope"]^2 + "      " AT(0,10).
	//PRINT "dist: " + signed_exponent(newNode["distToDest"] - preNode["distToDest"] + varConstants["maxDist"],0.75) + "      " AT (0,11).
	//PRINT "turn: " + signed_exponent(VANG(newNode["latLng"]:POSITION - preNode["latLng"]:POSITION,preNode["preNewVec"]),0.5) + "      " AT(0,12).
	//WAIT 1.
	RETURN score.
}

FUNCTION new_node_chord {
	PARAMETER nodeHeading,oldNode.//nodeHeading is degrees, oldNode is latLng to calculate new node form
	//LOCAL degTravle IS (varConstants["unitDist"]*180) / (SHIP:BODY:RADIUS * CONSTANT:PI).//degrees around the body, might make as constant
	LOCAL degTravle IS varConstants["unitDistDeg"].//degrees around the body
	LOCAL newLat IS ARCSIN(SIN(oldNode:LAT)*COS(degTravle) + COS(oldNode:LAT)*SIN(degTravle)*COS(nodeHeading)).
	IF newLat <> 90 {
		LOCAL newLng IS oldNode:LNG + ARCTAN2(SIN(nodeHeading)*SIN(degTravle)*COS(oldNode:LAT),COS(degTravle)-SIN(oldNode:LAT)*SIN(newLat)).
		RETURN LATLNG(newLat,newLng).
	} ELSE {
		RETURN LATLNG(newLat,0).
	}
}

FUNCTION deg_protect {
	PARAMETER deg.
	RETURN MOD(deg + 360,360).
}

FUNCTION signed_exponent {
	PARAMETER num,exp.
	IF num < 0 {
		RETURN -ABS(num)^exp.
	} ELSE IF num > 0 {
		RETURN num^exp.
	} ELSE {
		RETURN 0.
	}
}