IF NOT SHIP:UNPACKED AND SHIP:LOADED { PRINT "waiting for unpack". WAIT UNTIL SHIP:UNPACKED AND SHIP:LOADED. WAIT 1. PRINT "unpacked". }
IF NOT EXISTS("1:/lib/") {CREATEDIR("1:/lib/").}
IF NOT EXISTS("1:/threaded_prime.ks") {  COPYPATH("0:/threaded_prime.ks","1:/"). }
RUN threaded_prime.