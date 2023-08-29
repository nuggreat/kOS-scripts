PARAMETER tankTag.
ABORT OFF.
LOCAL sourceTanks IS SHIP:PARTSTAGGED(tankTag).
LOCAL destTanks IS LIST().

LOCAL sourceResources TO LIST().
FOR tank IN sourceTanks {	//populates sourceResources list baced on sourceTanks
	FOR res IN tank:RESOURCES {
		LOCAL found IS TRUE.
		FOR sourceRes IN sourceResources {
			IF sourceRes = res:NAME {
				SET found TO FALSE.
				BREAK.
			}
		}
		IF found {
			sourceResources:ADD(res:NAME).
		}
	}
}

FOR destPart IN SHIP:PARTS {	//populates destTanks list
	LOCAL partAdd IS FALSE.
	FOR destRes IN destPart:RESOURCES {
		FOR sourceRes IN sourceResources {
			IF sourceRes = destRes:NAME {
				SET partAdd TO TRUE.
				BREAK.
			}
		}
		IF partAdd { BREAK. }
	}
	IF partAdd {
		FOR sourcePart IN sourceTanks {
			IF  destPart = sourcePart {
				SET partAdd TO FALSE.
				BREAK.
			}
		}
	}
	IF partAdd {
		destTanks:ADD(destPart).
	}
}

FOR res IN sourceResources {	//for all sourceResources pump from sourcetanks to destTanks
	LOCAL filteredSource IS res_filter(res,sourceTanks).
	LOCAL filteredDest IS res_filter(res,destTanks).
	IF (filteredSource:LENGTH > 0) AND (filteredDest:LENGTH > 0) {
		FOR source IN filteredSource {
			IF source[1]:AMOUNT > 0 {
				FOR dest IN filteredDest {
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
	UNTIL (dest[1]:AMOUNT = finalAmount) OR (pump:STATUS = "Finished") OR (pump:STATUS = "Failed") OR ABORT {
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

FUNCTION balance {	//blaancses res levels in givin source list
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
	FOR tank IN tankList { IF tank[1]:ENABLED {
		IF (tank[1]:AMOUNT / tank[1]:CAPACITY) > precentLevel {
			tankSource:ADD(tank).
		} ELSE IF (tank[1]:AMOUNT / tank[1]:CAPACITY) < precentLevel {
			tankDest:ADD(tank).
		}
	}}
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
	LOCAL tanks IS LIST().
	FOR tank IN tankList {
		FOR tankRes IN tank:RESOURCES {
			IF tankRes:NAME = res { tanks:ADD(LIST(tank,tankRes)). }
		}
	}
	RETURN tanks.
}

FUNCTION rgb_gen {	//returns a color for highlighting
	PARAMETER partRes.
	LOCAL re IS MIN(ROUND((1 - partRes:AMOUNT / partRes:CAPACITY) * 511),255).
	LOCAL gr IS MIN(ROUND((partRes:AMOUNT / partRes:CAPACITY) * 511),255).
	RETURN RGBA(re,gr,0,0.01).
}