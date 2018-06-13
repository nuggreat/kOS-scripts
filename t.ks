LOCAL tempETA IS ETA:APOAPSIS.

CLEARSCREEN.

print ("This is rend script : " + tempETA).

RUN t0(tempETA, 0, 1).
wait 1.
RUN t0(tempETA, 0, 1).