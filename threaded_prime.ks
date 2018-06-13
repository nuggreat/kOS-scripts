ABORT OFF.
PARAMETER startNum IS 1,logData IS FALSE, logFile IS "0:/prime_numbers.txt".
LOCAL buffer IS CORE:MESSAGES.

IF SHIP:PARTSTAGGED("server"):LENGTH = 0 {
	SET CORE:PART:TAG TO "server".
}
IF CORE:PART:TAG = "server" {
	CLEARSCREEN.
	IF EXISTS(logFile) AND logData { DELETEPATH(logFile). }
	IF MOD(startNum,1) <> 0 { SET startNum TO ROUND(startNum,0). }
	IF MOD(startNum,2) = 0 { SET startNum TO startNum - 1. }
	IF startNum <= 1 {
		SET startNum TO 2. PRINT "1".
		IF logData { LOG "1" TO logFile. }
	}
	IF startNum = 2 {
		SET startNum TO 3. PRINT "2".
		IF logData { LOG "2" TO logFile. }
	}
	IF startNum = 3 {
		SET startNum TO 5. PRINT "3".
		IF logData { LOG "3" TO logFile. }
	}

	CORE:DOEVENT("open terminal").
	WAIT 1.
	LOCAL coreList IS LIST().
	LIST PROCESSORS IN coreList.
	LOCAL slaveCout IS 1.
	FOR thread IN coreList {
		IF thread:PART:TAG <> "server" {
			SET thread:PART:TAG TO "slave" + slaveCout.
			thread:CONNECTION:SENDMESSAGE(LIST(CORE:PART:TAG,"start")).//message telling slave cores to request data
			SET slaveCout TO slaveCout + 1.
		}
	}
	LOCAL doneCount IS SHIP:PARTSTAGGED("slave"):LENGTH.
	LOCAL curentNum IS startNum.
	LOCAL done IS FALSE.
	UNTIL done {
		WAIT UNTIL NOT buffer:EMPTY.
		UNTIL buffer:EMPTY {
			LOCAL signal IS buffer:POP().
			LOCAL packet IS signal:CONTENT.
			IF ABORT {
				FOR contact IN coreList {
					contact:CONNECTION:SENDMESSAGE(LIST(CORE:PART:TAG,"done")).
				}
				SET done TO TRUE.
			}
			IF packet[1] = "data" {
				IF packet[2] {
					PRINT packet[3].
					IF logData { LOG packet[3] TO logFile. }
				}
				local_connection(packet):SENDMESSAGE(LIST(CORE:PART:TAG,"num",curentNum)).
				SET curentNum TO curentNum + 2.
			}
		}
	}
	ABORT OFF.
} ELSE {
	PRINT "waiting for message".
	WAIT UNTIL NOT buffer:EMPTY.
	LOCAL signal IS buffer:POP().
	LOCAL packet IS signal:CONTENT.
	local_connection(packet):SENDMESSAGE(LIST(CORE:PART:TAG,"data",FALSE,1)).//false data message to get the initial number to calculate
	LOCAL done IS FALSE.
	UNTIL done {
		WAIT UNTIL NOT buffer:EMPTY.
		LOCAL signal IS buffer:POP().
		LOCAL packet IS signal:CONTENT.

		IF packet[1] = "done" {
			SET done TO TRUE.
			local_connection(packet):SENDMESSAGE(LIST(CORE:PART:TAG,"done")).
			WAIT UNTIL NOT buffer:EMPTY.
			buffer:CLEAR.
		} ELSE {
			IF packet[1] = "num" {
				LOCAL num IS packet[2].
				LOCAL passed IS FALSE.
				LOCAL countMax IS SQRT(num).
				LOCAL count IS 37.
				UNTIL FALSE {
					IF MOD(num,count) = 0 { IF num <> count { BREAK. }}
					SET count TO count + 2.
					IF	count > countMax {
						SET passed TO TRUE.
						BREAK.
					}
				}
				local_connection(packet):SENDMESSAGE(LIST(CORE:PART:TAG,"data",passed,num)).
			}
		}
	}
}

FUNCTION local_connection {
	PARAMETER data.
	RETURN SHIP:PARTSTAGGED(data[0])[0]:GETMODULE("kOSProcessor"):CONNECTION.
}