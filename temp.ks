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
	replyLex,//the lexicon of replies using the key as the means to request
	comTarget IS FALSE.

	LOCAL comMode IS 0.
	IF comTarget:ISTYPE("vessel") {
		requestLex:ADD("target",FALSE).
		responceData:ADD("comTarget",comTarget)
	} ELSE {
		requestLex:ADD("target",TRUE).
		SET comMode TO -1.
	}

	LOCAL requestLex IS LEX("handshake",TRUE,"echoDone",TRUE).
	FOR requestItem IN requestList { requestLex:ADD(requestItem,TRUE). }
	LOCAL responceData IS LEX().

	LOCAL comsDone IS LEX("self",FALSE,"target",FALSE).

	RETURN LEX(
	"comMode",comMode,
	"comTarget",comTarget.
	"requestList",requestList,
	"requestLex",requestLex,
	"responceData",responceData,
	"replyLex",replyLex,
	"comsDone",comsDone.
}

FUNCTION general_coms {
	PARAMETER formatedLex,buffer IS SHIP:MESSAGES,handshakeDelay IS 1.
	LOCAL comMode IS formatedLex["comMode"].
	LOCAL comTarget IS formatedLex["comTarget"].
	LOCAL requestList IS formatedLex["requestList"].
	LOCAL requestLex IS formatedLex["requestLex"].
	LOCAL responceData IS formatedLex["responceData"].
	LOCAL replyLex IS formatedLex["replyLex"]
	LOCAL comsDone IS formatedLex["comsDone"].

	LOCAL rejectedSignals IS QUEUE().
	UNTIL buffer:EMPTY {
		LOCAL signal IS buffer:POP().
		IF signal:SENDER = craft OR requestLex["target"] {
			LOCAL sType IS signal:CONTENT["type"].
			LOCAL sWhat IS signal:CONTENT["what"].
			LOCAL sData IS signal:CONTENT["data"].

			IF sType = "response" AND requestLex[sWhat] AND (NOT requestLex["target"]) {
				IF sWhat = "handshake" {
					SET requestLex[sWhat] TO FALSE.
				}
				IF requestList:CONTAINS(sWhat) {
					IF requestLex[sWhat] {
						responceData:ADD(sWhat,sData).
						SET requestLex[sWhat] TO FALSE.
					}
				}
				IF sWhat = "echoDone" {
					SET comsDone["self"] TO TRUE.
					SET requestLex[sWhat] TO FALSE.
				}
				PRINT "Received: " + sWhat.
			}
			IF sType = "request" {
				LOCAL printOut IS { PRINT "returning: " + sWhat. }
				IF sWhat = "handshake" {
					IF requestLex["target"] {
						responceData:ADD("comTarget",signal:SENDER).
						SET formatedLex["comTarget"] TO responceData["comTarget"]:CONNECTION.
						SET formatedLex["comMode"] TO 0.
						SET requestLex["target"] TO FALSE.
					}
					comTarget:SENDMESSAGE(message_creation("response",sType)).
					printOut().
				}
				IF NOT requestLex["target"] {
					IF repllyLex:KEYS:CONTAINS(sWhat) {
						comTarget:SENDMESSAGE(message_creation("response",sType,repllyLex[sWhat])).
						printOut().
					}
					IF sWhat = "echoDone" {
						comTarget:SENDMESSAGE(message_creation("response",sType)).
						SET comsDone["target"] TO TRUE.
						printOut().
					}
				}
			}
		} ELSE {
			rejectedSignals:PUSH(signal).
		}
	}

	IF comMode <> -1 AND (NOT requestLex["target"]) {
		IF comMode = 0 {
			IF requestLex["handshake"] {
				comTarget:SENDMESSAGE(message_creation("request","Handshake")).
				WAIT handshakeDelay.
			} ELSE { SET formatedLex["comMode"] TO 1. SET comMode TO 1. }
		}
		IF comMode = 1 {
			LOCAL haveAll IS TRUE.
			FOR getItem IN requestList. {
				IF requestLex[getItem] {
					comTarget:SENDMESSAGE(message_creation("request",getItem)).
					SET haveAll TO FALSE.
				}
			}
			IF haveAll { SET formatedLex["comMode"] TO 2. SET comMode TO 2. }
		}
		IF comMode = 2 {
			IF requestLex["echoDone"] {
				comTarget:SENDMESSAGE(message_creation("request","echoDone")).
			} ELSE { SET formatedLex["comMode"] TO -1. SET comMode TO -1. }
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
	PARAMETER formatedLex,dataRequest.
	RETURN NOT formatedLex["requestLex"][dataRequest].
}

FUNCTION get_data {
	PARAMETER formatedLex,dataRequest.
	RETURN formatedLex["responceData"][dataRequest].
}

FUNCTION add_reply {
	PARAMETER formatedLex,replyString,replyData.
	formatedLex["replyList"]:ADD(replyString).
	formatedLex["replyLex"]:ADD(replyString,replyData).
}

FUNCTION update_reply{
	PARAMETER formatedLex,replyString,replyData.
	SET formatedLex[replyString] TO replyData.
}