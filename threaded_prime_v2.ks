ABORT OFF.
PARAMETER curentNum IS 60000,maxNum IS -1,logData IS FALSE,primeFilter IS 0,logFile IS "0:/prime_numbers.txt".
LOCAL buffer IS CORE:MESSAGES.
buffer:CLEAR.

IF SHIP:PARTSTAGGED("server"):LENGTH = 0 {
	SET CORE:PART:TAG TO "server".
}
IF CORE:PART:TAG = "server" {
	delta_time().
	CLEARSCREEN.
	LOCAL primeList IS LIST().
	IF EXISTS(logFile) AND logData { DELETEPATH(logFile). }
	IF MOD(startNum,1) <> 0 { SET startNum TO ROUND(startNum,0). }
	IF MOD(curentNum,2) = 0 { SET curentNum TO curentNum - 1. }
	IF curentNum <= 1 {
		SET curentNum TO 2.
		primeList:ADD(1).
	}
	IF curentNum = 2 {
		SET curentNum TO 3.
		primeList:ADD(2).
	}
	IF curentNum = 3 {
		SET curentNum TO 5.
		primeList:ADD(3).
	}

	CORE:DOEVENT("open terminal").
	WAIT 1.

	LOCAL coreList IS LIST().
	LIST PROCESSORS IN coreList.
	LOCAL dataBuffer IS 10.
	LOCAL testList IS LIST().
	LOCAL countStart IS 3.
	UNTIL primeFilter <= testList:LENGTH {
		UNTIL is_prime(countStart,3) { SET countStart TO countStart + 2. }
		testList:ADD(countStart).
		IF curentNum <= countStart {
			primeList:ADD(countStart).
			SET curentNum TO countStart + 2.
		}
		SET countStart TO countStart + 2.
	}
	LOCAL slaveCout IS 0.
	FOR thread IN coreList {
		IF thread:PART:TAG <> "server" {
			SET thread:PART:TAG TO "slave" + slaveCout.
			thread:CONNECTION:SENDMESSAGE(LIST(CORE:PART:TAG,"start",dataBuffer,countStart)).
			SET slaveCout TO slaveCout + 1.
		}
	}

	LOCAL doneCount IS SHIP:PARTSTAGGED("slave"):LENGTH.
	LOCAL bufferMax IS dataBuffer * coreList:LENGTH.
	UNTIL primeList:LENGTH <= bufferMax {
		IF maxNum = -1 OR maxNum > primeList[0] {
			PRINT primeList[0].
			IF logData { LOG primeList[0] TO logFile. }
			primeList:REMOVE(0).
		} ELSE {
			ABORT ON.
		}
	}
	LOCAL done IS FALSE.
	UNTIL done {
		WAIT UNTIL NOT buffer:EMPTY.
		UNTIL buffer:EMPTY {
			LOCAL signal IS buffer:POP().
			LOCAL data IS signal:CONTENT.
			IF ABORT {
				FOR contact IN coreList {
					contact:CONNECTION:SENDMESSAGE(LIST(CORE:PART:TAG,"done")).
				}
				SET done TO TRUE.
			}
			IF data[1] = "data" {
				IF data[2] {
					LOCAL primeTemp IS data[3].
					IF primeList:LENGTH > 0 {
						LOCAL indexNum IS 0.
						FROM { LOCAL i IS primeList:LENGTH - 1. } UNTIL 0 = i STEP { SET i TO i - 1. } DO {
							IF primeList[i] < primeTemp { SET indexNum TO i + 1. BREAK. }
						}
						primeList:INSERT(indexNum,primeTemp).
					} ELSE { primeList:ADD(primeTemp). }

					UNTIL primeList:LENGTH <= bufferMax {
						IF maxNum = -1 OR maxNum > primeList[0] {
							PRINT primeList[0].
							IF logData { LOG primeList[0] TO logFile. }
							primeList:REMOVE(0).
						} ELSE {
							ABORT ON.
						}
					}
				}
				local_connection(data):SENDMESSAGE(LIST(CORE:PART:TAG,"num",curentNum)).

				SET curentNum TO curentNum + 2.
				IF testList:LENGTH > 0 {
					LOCAL numGood IS FALSE.
					UNTIL numGood {
						SET numGood TO TRUE.
						FOR testNum IN testList {
							IF curentNum = testNum { BREAK. }
							IF MOD(curentNum,testNum) = 0 {
								SET curentNum TO curentNum + 2.
								SET numGood TO FALSE.
								BREAK.
							}
						}
					}
				}
			}
		}
	}
	PRINT "Time Elapsed: " + ROUND(deltaTime(),2).
	ABORT OFF.
} ELSE {
	IF buffer:EMPTY { WAIT UNTIL NOT buffer:EMPTY. }
	LOCAL signal IS buffer:POP().
	LOCAL data IS signal:CONTENT.
	FROM { LOCAL i IS 1. } UNTIL data[2] < i STEP { SET i TO i + 1. } DO {
		local_connection(data):SENDMESSAGE(LIST(CORE:PART:TAG,"data",FALSE,i)).
	}
	LOCAL count IS data[3].
	LOCAL done IS FALSE.
	UNTIL done {
		WAIT UNTIL NOT buffer:EMPTY.
		LOCAL signal IS buffer:POP().
		LOCAL data IS signal:CONTENT.

		IF data[1] = "done" {
			SET done TO TRUE.
			local_connection(data):SENDMESSAGE(LIST(CORE:PART:TAG,"done")).
		} ELSE {
			IF data[1] = "num" {
				local_connection(data):SENDMESSAGE(LIST(CORE:PART:TAG,"data",is_prime(data[2],count),data[2])).
			}
		}
	}
}

FUNCTION is_prime {
	PARAMETER num,count IS 3.
	LOCAL countMax IS num ^ 0.5.
	LOCAL passed IS FALSE.
	UNTIL FALSE {
		IF MOD(num,count) = 0 { IF num <> count { BREAK. }}
		SET count TO count + 2.
		IF count > countMax {
			SET passed TO TRUE.
			BREAK.
		}
	}
	RETURN passed.
}

FUNCTION local_connection {
	PARAMETER data.
	RETURN SHIP:PARTSTAGGED(data[0])[0]:GETMODULE("kOSProcessor"):CONNECTION.
}

FUNCTION delta_time {
	IF NOT (DEFINED prevousTime) { GLOBAL prevousTime IS TIME:SECONDS. }
	LOCAL timeNow IS TIME:SECONDS.
	LOCAL deltaTime IS timeNow - prevousTime.
	SET prevousTime TO timeNow.
	RETURN deltaTime.
}