print eval_str("2e3/1_000-(0-(3+2*3))").
print 2/10^((2+1)-2).
FUNCTION eval_str {
  PARAMETER str,firstRun IS TRUE.
  
  LOCAL symbols IS LIST().
  IF firstRun {
    LOCAL tmpString IS "".
	FROM { LOCAL i IS str:LENGTH - 1. } UNTIL i < 0 STEP { SET i TO i - 1. } DO {
	  IF str[i]:MATCHESPATTERN("[0-9._eE()^*/+-]") {
	    IF str[i]:MATCHESPATTERN("[()^*/+-]") {
	      SET tmpString TO " " + str[i] + " " + tmpString.
		} ELSE {
	      SET tmpString TO str[i] + tmpString.
		}
	  }
	}
    SET symbols TO tmpString:SPLIT(" ").
	FROM { LOCAL i IS symbols:LENGTH - 1. } until i < 0 STEP { SET i TO i - 1. } DO {
	  IF symbols[i] = "" { symbols:REMOVE(i). }
	}
  } ELSE {
    SET symbols TO str.
  }
	
  IF symbols:ISTYPE("list") AND symbols:LENGTH = 1 {
    RETURN CHOOSE symbols[0]:TONUMBER() IF symbols[0]:ISTYPE("string") ELSE symbols[0].
  }
  
  IF symbols:ISTYPE("string") {
    RETURN symbols:TONUMBER().
  }
  
  IF symbols[0] = "-" {
    RETURN -eval_str(sub_set(symbols,1,symbols:LENGTH - 1),FALSE).
  }
  
  IF symbols:CONTAINS("(") {
    FROM { LOCAL i IS 0.} UNTIL i = symbols:LENGTH STEP { SET i TO i + 1. } DO {
      IF symbols[i] = "(" {
        LOCAL perenNum IS 1.
        LOCAL j IS i.
        UNTIL perenNum = 0 {
          SET j TO j + 1.
          IF symbols[j] = "(" {
            SET perenNum TO perenNum + 1.
          }
          IF symbols[j] = ")" {
            SET perenNum TO perenNum - 1.
          }
        }
        LOCAL perenRange IS (j-i) + 1.
        LOCAL perenResult IS eval_str(sub_set(symbols,i + 1,perenRange - 2),FALSE).
        replace_range(symbols,i,perenRange,perenResult).
      }
    }
  }
  
  symbol_itterate(symbols,"^",{ PARAMETER op,a,b. RETURN a^b. }).
  symbol_itterate(symbols,"*/",{ PARAMETER op,a,b. RETURN CHOOSE a*b IF op = "*" ELSE a/b. }).
  symbol_itterate(symbols,"+-",{ PARAMETER op,a,b. RETURN CHOOSE a+b IF op = "+" ELSE a-b. }).
  
  RETURN eval_str(symbols,FALSE).
}

LOCAL FUNCTION symbol_itterate {
  PARAMETER symbols,operationList,operation.
  FROM {LOCAL i IS 0.} UNTIL i = symbols:LENGTH STEP {SET i TO i + 1.} DO {
    IF operationList:CONTAINS(symbols[i]) {
      LOCAL a IS eval_str(symbols[i-1],FALSE).
      LOCAL b IS symbols[i+1].
      LOCAL stepI IS 3.
      IF b = "-" {
        SET b TO eval_str(sub_set(symbols,i + 1,2),FALSE).
        SET stepI TO 4.
      } ELSE {
	    SET b to eval_str(b).
	  }
      LOCAL result IS operation(symbols[i],a,b).
      replace_range(symbols,i-1,stepI,result).
      SET i TO i - 1.
    }
  }
}

LOCAL FUNCTION replace_range {
  PARAMETER symbols,startI,stepI,newVal.
  LOCAL endI IS startI + stepI.
  FROM { LOCAL i IS endI - 1. } UNTIL i <= startI STEP { SET i TO i - 1. } DO {
    symbols:REMOVE(i).
  }
  SET symbols[startI] TO CHOOSE newVal IF newVal:ISTYPE("string") ELSE newVal:TOSTRING().
}

LOCAL FUNCTION sub_set {
  PARAMETER baseList,startI,stepI.
  LOCAL endI IS startI + stepI.
  LOCAL returnList IS LIST().
  FROM { LOCAL i IS startI. } UNTIL i >= endI STEP { SET i TO i + 1. } DO {
    returnList:ADD(baseList[i]).
  }
  RETURN returnList.
}
