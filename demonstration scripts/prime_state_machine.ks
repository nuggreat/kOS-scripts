SET TERMINAL:WIDTH TO 50.
LOCAL regA IS 0.
LOCAL regB IS 0.
LOCAL regC IS 0.
LOCAL regD IS 0.
LOCAL runMode IS "start".

LOCAL prime IS LEXICON (
"start", {
	PRINT 2.
	SET regA TO 3.
	SET regB TO 3.
	SET regD TO 1.
	RETURN "primeCheck".
},
"incrementPrimeCanadate", {
	SET regA TO regA + 2.
	RETURN "updateLimit".
},
"updateLimit", {
	SET regD TO FLOOR(SQRT(regA)).
	RETURN "primeCheck".
},
"incrementFactor", {
	SET regB TO regB + 2.
	RETURN "primeCheck".
},
"primeCheck", {
	IF regD < regB {
		RETURN "isPrme".
	} ELSE {
		RETURN "mod".
	}
},
"isPrme", {
	PRINT regA.
	RETURN "nextNumber".
},
"mod", {
	SET regC TO MOD(regA,regB).
	RETURN "notPrimeCheck".
},
"notPrimeCheck", {
	IF regC = 0 {
		RETURN "nextNumber".
	} ELSE {
		RETURN "incrementFactor".
	}
},
"nextNumber", {
	SET regB TO 3.
	RETURN "incrementPrimeCanadate".
}).

CLEARSCREEN.
PRINT " ".
PRINT " ".
PRINT " ".
PRINT " ".
PRINT " ".
PRINT " ".

UNTIL FALSE {
	PRINT ("Current Runmode: " + runMode):PADRIGHT(40) AT(0,0).
	SET runMode TO prime[runMode]().
	PRINT ("Canadite Number: " + regA):PADRIGHT(40) AT(0,1).
	PRINT (" Current Factor: " + regB):PADRIGHT(40) AT(0,2).
	PRINT ("   Factor Limit: " + regD):PADRIGHT(40) AT(0,3).
	PRINT (" Modulis Result: " + regC):PADRIGHT(40) AT(0,4).
	PRINT ("   Next Runmode: " + runMode):PADRIGHT(40) AT(0,5).
	WAIT 1.
}