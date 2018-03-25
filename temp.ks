FUNCTION ship_coms {
LOCAL buffer IS SHIP:MESSAGES.
buffer:CLEAR().

LOCAL stationConect IS station:CONNECTION.
PRINT "Waiting for Handshake.".

LOCAL getLEX IS LEX("handshake",TRUE,"UID_List",TRUE,"noFlyZone",TRUE,"echoDone",TRUE).
LOCAL haveLEX IS LEX("UID_List",FALSE).
LOCAL comMode = 0.

LOCAL returnData IS LEX().

LOCAL craftDone IS FALSE.
LOCAL stationDone IS FALSE.
UNTIL craftDone AND stationDone {
	IF comMode <> -1 {
		IF comMode = 0 {
			IF getLEX["handshake"] {
				stationConect:SENDMESSAGE(message_creation("request","Handshake")).
				WAIT 1.
			} ELSE { SET comMode TO 1. }
		}
		IF comMode = 1 {
			IF getLEX["UID_List"] OR getLEX["noFlyZone"]) {
				IF getLEX["UID_List"] { stationConect:SENDMESSAGE(message_creation("request","UID_List")). }
				IF getLEX["noFlyZone"] { stationConect:SENDMESSAGE(message_creation("request","noFlyZone")). }
			} ELSE { SET comMode TO 2. }
		}
		IF comMode = 2 {
			IF getLEX["echoDone"] {
				stationConect:SENDMESSAGE(message_creation("request","echoDone")).
			} ELSE { SET comMode TO -1. }
		}
	}
	WAIT 0.01
	UNTIL buffer:EMPTY {
		LOCAL signal IS buffer:POP().
		LOCAL sType IS signal["type"].
		LOCAL sWhat IS signal["what"].
		LOCAL sData IS signal["data"].
		IF signal:SENDER = station {
			IF sType = "responce" AND getLEX[sWhat] {
				IF sWhat = "handshake" {
					SET getLEX[sWhat] TO FALSE.
				}
				IF sWhat = "UID_List" {
					LOCAL craftPortListRaw IS port_scan(SHIP).
					IF craftPortListRaw:LENGTH = 0 {SET craftPortListRaw TO port_scan(SHIP).}
					LOCAL portLock IS port_lock(port_uid_filter(craftPortListRaw),sData,"enabled","disabled").
					returnData:ADD("portLockUID",portLock)
					
					LOCAL stationPortListRaw IS port_scan(station).
					IF stationPortListRaw:LENGTH = 0 {SET stationPortListRaw TO port_scan(station).}
					returnData:ADD("portLock",port_lock_true(craftPortListRaw,stationPortListRaw,portLock))
					
					SET getLEX[sWhat] TO FALSE.
					SET haveLEX[sWhat] TO TRUE.
				}
				IF sWhat = "noFlyZone" {
					SET noFlyZone TO sData.
					returnData:ADD(sWhat,sData).
					SET getLEX[sWhat] TO FALSE.
				}
				IF sWhat = "echoDone" {
					SET craftDone TO TRUE.
					SET getLEX[sWhat] TO FALSE.
				}
				PRINT "Receved: " + sWhat.
			}
			IF sType = "request" {
				LOCAL printOut IS { PRINT "sending: " + sWhat. }
				IF sWhat = "handshake" {
					stationConect:SENDMESSAGE(message_creation("responce",sType)).
				}
				IF sWhat = "stationMove" {
					stationConect:SENDMESSAGE(message_creation("responce",sType,stationMove)).
					printOut().
				}
				IF sWhat = "portLock" AND haveLEX["UID_List"] {
					stationConect:SENDMESSAGE(message_creation("responce",sType,returnData["portLockUID"])).
					printOut().
				}
				IF sWhat = "echoDone" {
					stationConect:SENDMESSAGE(message_creation("responce",sType)).
					SET stationDone TO TRUE.
					printOut().
				}
			}
		}
	}
}
LOCAL noFlyZone IS returnData["noFlyZone"].
LOCAL portLock IS returnData["portLock"].
}



FUNCTION station_coms {
LOCAL buffer IS SHIP:MESSAGES.
buffer:CLEAR().
PRINT "Waiting for Handshake.".

LOCAL getLEX IS LEX("handshake",TRUE,"portLock",TRUE,"stationMove",TRUE,"echoDone",TRUE).
LOCAL haveLEX IS LEX("craft",FALSE).
LOCAL comMode = -1.

LOCAL returnData IS LEX().
LOCAL craftConect IS FALSE.

LOCAL stationPortListRaw IS port_scan(SHIP).
IF stationPortListRaw:LENGTH = 0 {SET stationPortListRaw TO port_scan(SHIP).}

LOCAL craftDone IS FALSE.
LOCAL stationDone IS FALSE.
UNTIL craftDone AND stationDone {
	IF comMode <> -1 {
		IF comMode = 0 {
			IF getLEX["handshake"] {
				craftConect:SENDMESSAGE(message_creation("request","Handshake")).
			} ELSE { SET comMode TO 1. }
		}
		IF comMode = 1 {
			IF getLEX["portLock"] OR getLEX["stationMove"]) {
				IF getLEX["portLock"] { craftConect:SENDMESSAGE(message_creation("request","portLock")). }
				IF getLEX["stationMove"] { craftConect:SENDMESSAGE(message_creation("request","stationMove")). }
			} ELSE { SET comMode TO 2. }
		}
		IF comMode = 2 {
			IF getLEX["echoDone"] {
				craftConect:SENDMESSAGE(message_creation("request","echoDone")).
			} ELSE { SET comMode TO -1. }
		}
	}
	WAIT 0.01
	UNTIL buffer:EMPTY {
		LOCAL signal IS buffer:POP().
		IF signal:SENDER = craft OR (NOT haveLEX["craft"]) {
			LOCAL sType IS signal["type"].
			LOCAL sWhat IS signal["what"].
			LOCAL sData IS signal["data"].
			
			IF sType = "responce" AND haveLEX["craft"] AND getLEX[sWhat] {
				IF sWhat = "handshake" {
					SET getLEX[sWhat] TO FALSE.
				}
				IF sWhat = "portLock" {
					returnData:ADD(sWhat,sData).
					SET getLEX[sWhat] TO FALSE.
				}
				IF sWhat = "stationMove" {
					returnData:ADD(sWhat,sData).
					SET getLEX[sWhat] TO FALSE.
				}
				IF sWhat = "echoDone" {
					SET stationDone TO TRUE.
					SET getLEX[sWhat] TO FALSE.
				}
				PRINT "Receved: " + sWhat.
			}
			IF sType = "request" {
				LOCAL printOut IS { PRINT "returning: " + sWhat. }
				IF sWhat = "handshake" {
					IF NOT haveLEX["craft"] {
						returnData:ADD("craft",signal:SENDER).
						SET craftConect TO returnData["craft"]:CONNECTION.
						SET comMode TO 0.
						SET haveLEX["craft"] TO TRUE.
					}
					craftConect:SENDMESSAGE(message_creation("responce",sType)).
					printOut().
				}
				IF sWhat = "UID_List" {
					craftConect:SENDMESSAGE(message_creation("responce",sType,port_uid_filter(stationPortListRaw))).
					printOut().
				}
				IF sWhat = "noFlyZone" {
					craftConect:SENDMESSAGE(message_creation("responce",sType,noFlyZone)).
					printOut().
				}
				IF sWhat = "echoDone" {
					craftConect:SENDMESSAGE(message_creation("responce",sType)).
					SET craftDone TO haveLEX["craft"].
					printOut().
				}
			}
		}
	}
}
LOCAL craftPortListRaw IS port_lock_true(craftPortListRaw,stationPortListRaw,port_scan(returnData["craft"])).
IF stationPortListRaw:LENGTH = 0 {SET stationPortListRaw TO port_scan(SHIP).}
LOCAL portLock IS returnData["portLock"].
LOCAL stationMove IS returnData["stationMove"].
LOCAL craft IS returnData["craft"].
}

{
LOCAL comsData IS coms_formater(
	LIST("UID_List","noFlyZone"),
	LIST("stationMove"),
	LEX("stationMove",stationMove)
	).
	IF have_data(comsData,"UID_List") {
		SET portLock TO port_lock(port_uid_filter(craftPortListRaw),get_data("UID_List"),"enabled","disabled").
		add_reply(comsData,"portLock",portLock).
	}
}//ship format

{
LOCAL comsData IS coms_formater(
	LIST("portLock","stationMove"),
	LIST("UID_List","noFlyZone"),
	LEX("UID_List",port_uid_filter(stationPortListRaw),"noFlyZone",noFlyZone)
	).
}//station format

FUNCTION coms_formater {
	PARAMETER requestList,//list of strings
	replyList,//list of strings
	replyData,//lex with one item for every item in replyList
	comTarget IS FALSE.
	
	LOCAL comMode IS 0.
	IF comTarget:ISTYPE("vessel") {
		requestLEX:ADD("target",FALSE).
		responceData:ADD("comTarget",comTarget)
	} ELSE {
		requestLEX:ADD("target",TRUE).
		SET comMode TO -1.
	}
	
	LOCAL requestLEX IS LEX("handshake",TRUE,"echoDone",TRUE).
	FOR requestItem IN requestList { requestLEX:ADD(requestItem,TRUE). }
	LOCAL responceData IS LEX().
	
	LOCAL comsDone IS LEX("self",FALSE,"target",FALSE).
	
	RETURN LEX(
	"comMode",comMode,
	"comTarget",comTarget.
	"requestList",requestList,
	"requestLEX",requestLEX,
	"responceData",responceData.
	"replyList",replyList,
	"replyData",replyData,
	"comsDone",comsDone,
}

FUNCTION general_coms {
	PARAMETER formatedLEX,buffer IS SHIP:MESSAGES,handshakeDelay IS 1.
	LOCAL comMode IS formatedLEX["comMode"].
	LOCAL comTarget IS formatedLEX["comTarget"].
	LOCAL requestList IS formatedLEX["requestList"].
	LOCAL requestLEX IS formatedLEX["requestLEX"].
	LOCAL responceData IS formatedLEX["responceData"].
	LOCAL replyList IS formatedLEX["replyList"].
	LOCAL replyData IS formatedLEX["replyData"].
	LOCAL comsDone IS formatedLEX["comsDone"].
	
	LOCAL rejectedSignals IS QUEUE().
	UNTIL buffer:EMPTY {
		LOCAL signal IS buffer:POP().
		IF signal:SENDER = craft OR requestLEX["target"] {
			LOCAL sType IS signal:CONTENT["type"].
			LOCAL sWhat IS signal:CONTENT["what"].
			LOCAL sData IS signal:CONTENT["data"].
			
			IF sType = "responce" AND requestLEX[sWhat] AND (NOT requestLEX["target"]) {
				IF sWhat = "handshake" {
					SET requestLEX[sWhat] TO FALSE.
				}
				IF requestList:CONTAINS(sWhat) {
					IF requestLEX[sWhat] {
						responceData:ADD(sWhat,sData).
						SET requestLEX[sWhat] TO FALSE.
					}
				}
				IF sWhat = "echoDone" {
					SET comsDone["self"] TO TRUE.
					SET requestLEX[sWhat] TO FALSE.
				}
				PRINT "Receved: " + sWhat.
			}
			IF sType = "request" {
				LOCAL printOut IS { PRINT "returning: " + sWhat. }
				IF sWhat = "handshake" {
					IF requestLEX["target"] {
						responceData:ADD("comTarget",signal:SENDER).
						SET formatedLEX["comTarget"] TO responceData["comTarget"]:CONNECTION.
						SET formatedLEX["comMode"] TO 0.
						SET requestLEX["target"] TO FALSE.
					}
					comTarget:SENDMESSAGE(message_creation("responce",sType)).
					printOut().
				}
				IF NOT requestLEX["target"] {
					IF replyList:CONTAINS(sWhat) {
						comTarget:SENDMESSAGE(message_creation("responce",sType,replyData[sWhat])).
						printOut().
					}
					IF sWhat = "echoDone" {
						comTarget:SENDMESSAGE(message_creation("responce",sType)).
						SET comsDone["target"] TO TRUE.
						printOut().
					}
				}
			}
		} ELSE {
			rejectedSignals:PUSH(signal).
		}
	}
	
	IF comMode <> -1 AND (NOT requestLEX["target"]) {
		IF comMode = 0 {
			IF requestLEX["handshake"] {
				comTarget:SENDMESSAGE(message_creation("request","Handshake")).
				WAIT handshakeDelay.
			} ELSE { SET formatedLEX["comMode"] TO 1. SET comMode TO 1. }
		}
		IF comMode = 1 {
			LOCAL haveAll IS TRUE.
			FOR getItem IN requestList. {
				IF requestLEX[getItem] {
					comTarget:SENDMESSAGE(message_creation("request",getItem)).
					SET haveAll TO FALSE.
				}
			}
			IF haveAll { SET formatedLEX["comMode"] TO 2. SET comMode TO 2. }
		}
		IF comMode = 2 {
			IF requestLEX["echoDone"] {
				comTarget:SENDMESSAGE(message_creation("request","echoDone")).
			} ELSE { SET formatedLEX["comMode"] TO -1. SET comMode TO -1. }
		}
	}
	
	RETURN rejectedSignals.
}

FUNCTION message_creation {
	PARAMETER mType,mWhat,mData IS 0.
	IF mType = "responce" {
		RETURN LEX("type",mType,"what",mWhat,"data",mData).
	} ELSE IF mtype = "request" {
		RETURN LEX("type",mType,"what",mWhat).
	}
}

FUNCTION have_data {
	PARAMETER formatedLEX,dataRequest.
	RETURN NOT formatedLEX["requestLEX"][dataRequest].
}

FUNCTION get_data {
	PARAMETER formatedLEX,dataRequest.
	RETURN formatedLEX["responceData"][dataRequest].
}

FUNCTION add_reply {
	PARAMETER formatedLEX,replyString,replyData.
	formatedLEX["replyList"]:ADD(replyString).
	formatedLEX["replyData"]:ADD(replyString,replyData).
}

FUNCTION update_reply{
	PARAMETER formatedLEX,replyString,replyData.
	SET formatedLEX[replyString] TO replyData.
}