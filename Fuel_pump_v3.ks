PARAMETER tankTag,pumpOut IS TRUE.
ABORT OFF.
LOCAL tagedTanks IS SHIP:PARTSTAGGED(tankTag).
LOCAL notTagedTanks IS LIST().

LOCAL resourceList TO LIST().
FOR tank IN tagedTanks {	//populates resourceList list baced on sourceTanks
	FOR res IN tank:RESOURCES {
		IF NOT resourceList:CONTAINS(res:NAME) {
			resourceList:ADD(res:NAME).
		}
	}
}
FOR notTaged IN SHIP:PARTS { //populates all tanks with out the tag tankTag and with a resource in resourceList
	IF notTaged:TAG <> tankTag {
		FOR destRes IN notTaged:RESOURCES {
			IF resourceList:CONTAINS(destRes:NAME) {
				notTagedTanks:ADD(notTaged).
				BREAK.
			}
		}
	}
}

LOCAL sourceTanks IS LIST().
LOCAL destTanks IS LIST().
IF pumpOut {
	SET sourceTanks TO tagedTanks.
	SET destTanks TO notTagedTanks.
} ELSE {
	SET destTanks TO tagedTanks.
	SET sourceTanks TO notTagedTanks.
}

FOR res IN resourceList {	//for all resourceList pump from sourcetanks to destTanks
	LOCAL filteredSource IS res_filter(res,sourceTanks).
	LOCAL filteredDest IS res_filter(res,destTanks).
	IF (filteredSource:LENGTH > 0) AND (filteredDest:LENGTH > 0) {
		FOR source IN filteredSource {
			FOR dest IN filteredDest {
				IF source[1]:AMOUNT > 0 {
					IF dest[1]:CAPACITY - dest[1]:AMOUNT > 0 {
						LOCAL pumpAmount IS dest[1]:CAPACITY - dest[1]:AMOUNT.
						IF pumpAmount > source[1]:AMOUNT {SET pumpAmount TO source[1]:AMOUNT. }
						IF pumpAmount > 0 { pump_fuel(res,source,dest,pumpAmount). }
					}
				}
			}
		}
	balance(res,filteredSource).
	balance(res,filteredDest).
	}
}

//-----end of core logic start of functions-----
FUNCTION pump_fuel {	//pumps givin pumpAmount of res from source to dest
	PARAMETER res,source,dest,pumpAmount.
	LOCAL finalAmount IS dest[1]:AMOUNT + pumpAmount.
	LOCAL pump IS TRANSFER(res,source[0],dest[0],pumpAmount).
	SET pump:ACTIVE TO TRUE.
	LOCAL sourceHL IS HIGHLIGHT(source,rgb_gen(source[1])).
	LOCAL destHL IS HIGHLIGHT(dest,rgb_gen(dest[1])).
	SET sourceHL:ENABLED TO TRUE.
	SET destHL:ENABLED TO TRUE.
	WAIT 0.01.
	UNTIL (dest[1]:AMOUNT >= finalAmount) OR (pump:STATUS = "Finished") OR (pump:STATUS = "Failed") OR ABORT {
		CLEARSCREEN.
		PRINT "        Transfering: " + res.
		PRINT "Amount Left to Move: " + ROUND(finalAmount - dest[1]:AMOUNT,2).
		PRINT "             Status: " + pump:STATUS.
		SET sourceHL:COLOR TO rgb_gen(source[1]).
		SET destHL:COLOR TO rgb_gen(dest[1]).
		WAIT 0.01.
	}
	ABORT OFF.
	SET sourceHL:ENABLED TO FALSE.
	SET destHL:ENABLED TO FALSE.
}

FUNCTION balance {	//blaancses res levels in given tankList
	PARAMETER res,tankList.
	LOCAL totalCap IS 0.
	LOCAL totalAmo IS 0.
	FOR tank IN tankList {
		IF tank[1]:ENABLED {
			SET totalCap to totalCap + tank[1]:CAPACITY.
			SET totalAmo to totalAmo + tank[1]:AMOUNT.
		}
	}
	IF totalCap = 0{SET totalCap TO 1.}
	LOCAL precentLevel IS totalAmo / totalCap.
	LOCAL tankSource IS LIST().
	LOCAL tankDest IS LIST().
	FOR tank IN tankList {
		IF tank[1]:ENABLED {
			IF (tank[1]:AMOUNT / tank[1]:CAPACITY) > precentLevel {
				tankSource:ADD(tank).
			} ELSE IF (tank[1]:AMOUNT / tank[1]:CAPACITY) < precentLevel {
				tankDest:ADD(tank).
			}
		}
	}
	IF (tankSource:LENGTH > 0) AND (tankDest:LENGTH > 0) {
		FOR source IN tankSource {
			FOR dest IN tankDest {
				LOCAL pumpAmount IS dest[1]:CAPACITY * precentLevel - dest[1]:AMOUNT.
				IF pumpAmount > source[1]:AMOUNT - source[1]:CAPACITY * precentLevel {
					SET pumpAmount TO  source[1]:AMOUNT - source[1]:CAPACITY * precentLevel.
				}
				IF pumpAmount > 0 { pump_fuel(res,source,dest,pumpAmount). }
			}
		}
	}
}

FUNCTION res_filter {	//filters tankList for givin res
	PARAMETER res,tankList.
	LOCAL filteredTanks IS LIST().
	FOR tank IN tankList {
		FOR tankRes IN tank:RESOURCES {
			IF tankRes:NAME = res {
				filteredTanks:ADD(LIST(tank,tankRes)).
				BREAK.
			}
		}
	}
	RETURN filteredTanks.
}

FUNCTION rgb_gen {	//returns a color for highlighting
	PARAMETER partRes.
	LOCAL re IS MIN(ROUND((1 - partRes:AMOUNT / partRes:CAPACITY) * 511),255).
	LOCAL gr IS MIN(ROUND((partRes:AMOUNT / partRes:CAPACITY) * 511),255).
	RETURN RGBA(re,gr,0,0.01).
}