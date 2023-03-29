PRINT " ".
LOCAL runMult IS 1.
LOCAL totalCalls IS FLOOR(runMult) * CONFIG:IPU.
LOCAL opCodeFrac IS totalCalls / CONFIG:IPU * 0.02.

WAIT 0.
LOCAL startTime IS TIME:SECONDS.
FROM { LOCAL i IS 0. } UNTIL i >= totalCalls STEP { SET i TO i + 1. } DO {

}
LOCAL tDelta IS TIME:SECONDS - startTime.
PRINT "Function A".
PRINT "   Execution Time: " + ROUND(tDelta,2).
PRINT "Estimated OPcodes: " + ROUND(tDelta / opCodeFrac - 12).//the loop it's self takes approximately 12 OPcodes
PRINT " ".

WAIT 0.
LOCAL startTime IS TIME:SECONDS.
FROM { LOCAL i IS 0. } UNTIL i >= totalCalls STEP { SET i TO i + 1. } DO {

}
LOCAL tDelta IS TIME:SECONDS - startTime.
PRINT "Function B".
PRINT "   Execution Time: " + ROUND(tDelta,2).
PRINT "Estimated OPcodes: " + ROUND(tDelta / opCodeFrac - 12).//the loop it's self takes approximately 12 OPcodes
