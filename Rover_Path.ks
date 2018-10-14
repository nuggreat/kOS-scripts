FOR lib IN LIST("lib_geochordnate") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
PARAMETER endPoint,unitDist IS 200,maxSpeed IS 20,minSpeed IS 5,closeToDist IS 450,waypointRadius IS 50.
CLEARSCREEN.
ABORT OFF.
SET CONFIG:IPU TO 2000.
LOCAL varConstants IS LEX().
LOCAL nodeTree IS LEX().
LOCAL nodeQue IS LIST().

LOCAL destData IS mis_types_to_geochordnate(endPoint).
LOCAL dest IS destData["chord"].
LOCAL destName IS destData["name"].
LOCAL doRoving IS FALSE.
LOCAL pruneCountDown IS 1000.
IF dest:ISTYPE("geocoordinates") { SET doRoving TO TRUE.}

IF doRoving {

LOCAL initalDist IS dist_between_coordinates(dest,SHIP:GEOPOSITION).
//LOCAL unitDist IS initalDist / 5^CEILING(LN(initalDist / MIN(100,(closeToDist / 2))) / LN(5)).
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
					   
	"nodeCluster",LIST(LIST( 0, 2),
					   LIST( 1, 1),
					   LIST( 1,-1),
					   LIST( 0,-2),
					   LIST(-1,-1),
					   LIST(-1, 1))
	).

LOCAL starNodeChord IS SHIP:GEOPOSITION.
nodeTree:ADD("0,0",LEX("latLng",starNodeChord)).
LOCAL localNode IS nodeTree["0,0"].
localNode:ADD("distToDest",dist_between_coordinates(starNodeChord,varConstants["dest"])).
localNode:ADD("alt",starNodeChord:TERRAINHEIGHT).
localNode:ADD("slope",slope_calculation(starNodeChord)).
localNode:ADD("preNewVec",V(0,0,0)).
localNode:ADD("preDist",1).
localNode:ADD("grade",0).
//localNode:ADD("totalDist",1).
localNode:ADD("prevousNodeID","0,0").
localNode:ADD("totalScore",0).
localNode:ADD("nodeScore",0).
nodeQue:ADD("0,0").

LOCAL waypointList IS LIST().
LOCAL startDist IS localNode["distToDest"].
LOCAL closestDist IS startDist - 0.01.
PRINT "   closest Dist: " + ROUND(closestDist) AT(0,3).
LOCAL bestVec IS VECDRAW(SHIP:POSITION,SHIP:UP:VECTOR * 500, GREEN,"",1,TRUE,50).
LOCAL nodeVec IS VECDRAW(SHIP:POSITION,SHIP:UP:VECTOR * 500, YELLOW,"",1,TRUE,50).
LOCAL endVecDraw IS VECDRAW(dest:POSITION,(dest:POSITION - SHIP:BODY:POSITION):NORMALIZED * 500,RED,"",1,TRUE,50).
LOCAL done IS FALSE.
LOCAL startTime IS TIME:SECONDS.
UNTIL done OR ABORT {
	LOCAL nodeID IS nodeQue[0].
	nodeQue:REMOVE(0).
	LOCAL nodeDist IS nodeTree[nodeID]["distToDest"].
	IF nodeDist < closeToDist {
		//IF back_propogation_check(nodeID,TRUE) {
			SET done TO TRUE.
			SET waypointList TO back_propogation_waypoint_list(nodeID).
		//} ELSE {
		//	SET closestDist TO startDist - 0.01.
		//	SET nodeDist TO startDist.
		//	prune_que().
		//}
	} ELSE {
		evaluate_node_cluster(nodeID).
	}
	IF nodeDist < closestDist {
		SET closestDist TO ROUND(nodeDist).
		LOCAL pointPos IS nodeTree[nodeID]["latLng"]:POSITION.
		SET bestVec:START TO pointPos.
		SET bestVec:VEC TO (pointPos - SHIP:BODY:POSITION):NORMALIZED * 200.
		PRINT "   closest Dist: " + closestDist + "      " AT(0,3).
		PRINT " Time Remaining: " + ROUND(closestDist / ((startDist - closestDist) / (TIME:SECONDS - startTime))) + "    " AT(0,4).
	}
	//IF pruneCountDown < 0 {
	//	prune_que().
	//	SET pruneCountDown TO nodeQue:LENGTH * 5.
	//} ELSE {
	//	SET pruneCountDown TO pruneCountDown - 1.
	//}
	LOCAL pointPos IS nodeTree[nodeID]["latLng"]:POSITION.
	SET nodeVec:START TO pointPos.
	SET nodeVec:VEC TO (pointPos - SHIP:BODY:POSITION):NORMALIZED * 200.
	PRINT "number of Nodes: " + nodeQue:LENGTH + "      " AT(0,2).
}
IF NOT ABORT {
	waypointList:ADD(dest).
	PRINT "elapsed time: " + ROUND(TIME:SECONDS - startTime) AT(0,7).
	PRINT "tree size: " + nodeTree:LENGTH AT(0,8).
	PRINT "path size: " + waypointList:LENGTH AT(0,9).
	render_points(waypointList).

	SET waypointList TO smooth_points(waypointList).
	render_points(waypointList).

	SET waypointList TO smooth_points(waypointList).
	render_points(waypointList).

//	SET waypointList TO smooth_points(waypointList).
//	render_points(waypointList).

	RCS OFF.
	SAS OFF.
	WAIT UNTIL RCS.
	CLEARVECDRAWS().

	SET CONFIG:IPU TO 200.
	IF NOT SAS {
		COPYPATH("0:/Rover_Path_execution.ks","1:/").
		RUNPATH("1:/Rover_Path_execution",maxSpeed,minSpeed,closeToDist,waypointList,waypointRadius,destName).
	}
}}
CLEARVECDRAWS().

FUNCTION render_points  {
	PARAMETER pointList.
	CLEARVECDRAWS().
	LOCAL renderedVectors IS LIST().
	LOCAL prevousPoint IS SHIP:GEOPOSITION.
	FOR point IN pointList {
		WAIT 0.
		LOCAL pointPos IS point:POSITION.
		LOCAL adjustPos IS pointPos + ((pointPos - SHIP:BODY:POSITION):NORMALIZED * 20).
		LOCAL prePos IS prevousPoint:POSITION.
		LOCAL adjPrePos IS prePos + ((prePos - SHIP:BODY:POSITION):NORMALIZED * 20).
		renderedVectors:ADD(VECDRAW(adjPrePos,(adjustPos - adjPrePos),green,"",1,TRUE,20)).
		SET prevousPoint TO point.
	}
	//WAIT 5.
}

FUNCTION back_propogation_check {
	PARAMETER initalNodeID,doPrint IS FALSE,errorRange IS 1.
	LOCAL nodeID IS initalNodeID.
	LOCAL endScore IS nodeTree[nodeID]["totalScore"].
	LOCAL recalcedScore IS nodeTree[nodeID]["nodeScore"].
	LOCAL done IS FALSE.
	UNTIL nodeID = "0,0" OR done{
		IF nodeTree:HASKEY(nodeID) {
			SET nodeID TO nodeTree[nodeID]["prevousNodeID"].
			SET recalcedScore TO recalcedScore + nodeTree[nodeID]["nodeScore"].
		} ELSE {
			SET done TO TRUE.
		}
	}
	LOCAL scoreError IS endScore - recalcedScore.
	IF doPrint { PRINT "scoreError: " + ROUND(scoreError,2) + "      " AT(0,5). }
	RETURN (ABS(scoreError) < errorRange) AND NOT done.
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

FUNCTION smooth_points {
	PARAMETER pointList.
	LOCAL pointLength IS pointList:LENGTH - 1.
	LOCAL returnList IS LIST(pointList[0]).
	FROM { LOCAL i IS 1. } UNTIL i >= pointLength STEP { SET i TO i + 1. } DO {
		LOCAL posTemp IS (pointList[i - 1]:POSITION + pointList[i]:POSITION + pointList[i + 1]:POSITION)/3.
		returnList:ADD(SHIP:BODY:GEOPOSITIONOF(posTemp)).
	}
	returnList:ADD(pointList[pointLength]).
	RETURN returnList.
}

FUNCTION evaluate_node_cluster {
	PARAMETER preNodeID.
	//IF back_propogation_check(preNodeID) {
		LOCAL nodeID IS preNodeID:SPLIT(",").
		FOR point IN varConstants["nodeCluster"] {
			LOCAL newNodeID IS newID(nodeID,point).
			IF evaluate_node(preNodeID,preNodeID,newNodeID[0],newNodeID[1]) {
				add_node_to_que(newNodeID[0]).
			}
		}
	//}
}

FUNCTION prune_que {
	LOCAL queLength IS nodeQue:LENGTH.
	FROM { LOCAL i IS queLength - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
		PRINT "pruned: " + ROUND((1 - i / queLength) * 100,2) + "%    " AT(0,6).
		IF NOT back_propogation_check(nodeQue[i]) {
			nodeQue:REMOVE(i).
		}
	}
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
		nodeQue:ADD(nodeID).
	} ELSE {
		LOCAL nodeScore IS nodeTree[nodeID]["totalScore"].
		LOCAL queIncrement IS MAX(FLOOR(queLength / 2),1).
		LOCAL queIndex IS MAX(queIncrement - 1,0).
		LOCAL divCounter IS FLOOR(LN(queLength) / LN(2)).
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
					SET queIndex TO ROUND(queIndex).
				}
			} ELSE {
				IF nodeTree[nodeQue[queIndex]]["totalScore"] < nodeScore {
					SET queIndex TO MIN(queIndex + 1,queLength).
					IF (queIndex >= queLength) OR (nodeTree[nodeQue[queIndex]]["totalScore"] >= nodeScore) {
						nodeQue:INSERT(queIndex,nodeID).
						BREAK.
					}
				} ELSE {
					IF queIndex <= 0 {
						nodeQue:INSERT(queIndex,nodeID).
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
		LOCAL preNodeChord IS preNode["latLng"].
		LOCAL oldTotalScore IS localNode["totalScore"].
		LOCAL oldGrade IS localNode["grade"].
		LOCAL oldPreDist IS localNode["preDist"].
		SET localNode["preDist"] TO dist_between_coordinates(preNodeChord,localNode["latLng"]).
		SET localNode["grade"] TO ARCTAN((preNode["alt"] - localNode["alt"]) / localNode["preDist"]).
		LOCAL newNodeScore IS node_score(preNodeID,newNodeIDstr).
		LOCAL newTotalScore IS preNode["totalScore"] + newNodeScore.
		IF newTotalScore < oldTotalScore {
			remove_from_que(newNodeIDstr,oldTotalScore).
			SET localNode["preNewVec"] TO localNode["latLng"]:POSITION - preNodeChord:POSITION.
			SET localNode["prevousNodeID"] TO preNodeID.
			SET localNode["nodeScore"] TO newNodeScore.
			SET localNode["totalScore"] TO newTotalScore.
			SET isBetter TO TRUE.
		} ELSE {
			SET localNode["grade"] TO oldGrade.
			SET localNode["preDist"] TO oldPreDist.
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
		localNode:ADD("grade",ARCTAN((preNode["alt"] - localNode["alt"]) / localNode["preDist"])).
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
					//PRINT "checking high: " + nodeQue[queHighScan] AT(0,7).
					IF nodeQue[queHighScan] = nodeID {

						nodeQue:REMOVE(queHighScan).
						BREAK.
					} ELSE {
						SET queHighScan TO queHighScan + 1.
					}
				}
				IF queLowScan >= 0 {
					//PRINT "checking low: " + nodeQue[queHighScan] AT(0,8).
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

FUNCTION node_score {
	PARAMETER preNodeID,newNodeID.
	LOCAL preNode IS nodeTree[preNodeID].
	LOCAL newNode IS nodeTree[newNodeID].
	LOCAL nodeDist IS dist_between_coordinates(preNode["latLng"],newNode["latLng"]) + 0.000001.
	//LOCAL score IS 0.
	//LOCAL score IS SIN(ARCTAN(ABS(preNode["alt"] - newNode["alt"]) / nodeDist)) * newNode["preDist"] * 2.//may need to add a div0 protect
	LOCAL score IS SIN(ABS(newNode["grade"] - preNode["grade"])) * newNode["preDist"] * 2.
	SET score TO score + SIN(newNode["slope"]) * newNode["preDist"] * 4.
	//SET score TO score + ((newNode["distToDest"] - preNode["distToDest"] + newNode["preDist"] / 2) / varConstants["maxDist"]).//negative when going towards dest
	//SET score TO score + (newNode["preDist"] / varConstants["maxDist"]).
	//SET score TO score + SIN(VANG(newNode["latLng"]:POSITION - preNode["latLng"]:POSITION,preNode["preNewVec"]) * newNode["preDist"]).//a measure of turn angle

	//LOCAL score IS (ARCTAN(ABS(preNode["alt"] - newNode["alt"]) / nodeDist)^3).//may need to add a div0 protect
	//SET score TO score + newNode["slope"]^2.
	SET score TO score + pos_boost(newNode["distToDest"] - preNode["distToDest"],2).//negative when going towards dest
	SET score TO score + newNode["preDist"] / 1.5.
	//SET score TO score + (VANG(newNode["latLng"]:POSITION - preNode["latLng"]:POSITION,preNode["preNewVec"])^0.5).//a measure of turn angle
	//PRINT "slope: " + newNode["slope"]^2 + "      " AT(0,10).
	//PRINT "dist: " + signed_exponent(newNode["distToDest"] - preNode["distToDest"] + varConstants["maxDist"],0.75) + "      " AT (0,11).
	//WAIT 1.
	RETURN score.
}

FUNCTION new_node_chord {
	PARAMETER nodeHeading,oldNode.//nodeHeading is degrees, oldNode is latLng to calculate new node form
	//LOCAL degTravle IS (varConstants["unitDist"]*180) / (SHIP:BODY:RADIUS * CONSTANT:PI).//degrees around the body, might make as constant
	LOCAL degTravle IS varConstants["unitDistDeg"].//degrees around the body
	LOCAL codDegT IS COS(degTravle).
	LOCAL sinDegTcosOldNlat IS SIN(degTravle)*COS(oldNode:LAT).
	LOCAL sinOldNlat IS SIN(oldNode:LAT).
	LOCAL newLat IS ARCSIN(sinOldNlat*codDegT + sinDegTcosOldNlat*COS(nodeHeading)).
	IF newLat <> 90 {
		LOCAL newLng IS oldNode:LNG + ARCTAN2(SIN(nodeHeading)*sinDegTcosOldNlat,codDegT-sinOldNlat*SIN(newLat)).
		RETURN LATLNG(newLat,newLng).
	} ELSE {
		RETURN LATLNG(newLat,0).
	}
}

FUNCTION pos_boost {
	PARAMETER num,factor.
	IF num > 0 {
		RETURN num * factor.
	} ELSE {
		RETURN num.
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