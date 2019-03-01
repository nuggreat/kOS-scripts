IF NOT SHIP:UNPACKED AND SHIP:LOADED { PRINT "waiting for unpack". WAIT UNTIL SHIP:UNPACKED AND SHIP:LOADED. WAIT 1. PRINT "unpacked". }
SET CORE:PART:TAG TO "charge_controler".
//use notes: all capacitors are assumed to be the same size, craft is assumed to have the EC capacity to hold more than the full discharge of a capacitor 
WAIT 1.
CLEARSCREEN.
PRINT "Charge Control Active".

LOCAL capControlers IS SHIP:PARTSTAGGED("charge_controler").
LOCAL isControlCore IS am_control_core(capControlers).
LOCAL capModuleList IS SHIP:MODULESNAMED("dischargeCapacitor").

ON SHIP:PARTS:LENGTH {//detection of docking events
	SET ec TO get_ec().
	SET numberOfParts TO SHIP:PARTS:LENGTH.
	SET newScanTime TO TIME:SECONDS - 1.
	PRESERVE.
}

LOCAL newScanTime IS TIME:SECONDS + 10.
WHEN TIME:SECONDS > newScanTime THEN {
	SET newScanTime TO newScanTime + (RANDOM() * 9 + 1).
	LOCAL localCapControlers IS SHIP:PARTSTAGGED("charge_controler").
	IF capControlers <> localCapControlers {
		SET capControlers TO localCapControlers.
		SET isControlCore TO am_control_core(capControlers).
		SET capModuleList TO SHIP:MODULESNAMED("dischargeCapacitor").
	}
	PRESERVE.
}

LOCAL maxCharge IS max_charge(capModuleList).
LOCAL ec IS get_ec().
LOCAL dumpRate IS (maxCharge / 10).
LOCAL chargeThreshold IS ec:CAPACITY - dumpRate.
LOCAL dumpThreshold IS chargeThreshold - maxCharge.
LOCAL dumpHist IS dumpThreshold.

LOCAL oldEC is ec:AMOUNT.
LOCAL oldTime IS TIME:SECONDS.
WAIT 0.

UNTIL FALSE {
	IF not_warping() {
		//CLEARSCREEN.
		LOCAL deltaEc IS delta_ec(ec).
		//PRINT "dc: " + deltaEc + "    " AT(0,0).
		LOCAL canCharge IS deltaEc > 0.
		LOCAL ecLevel IS ec:AMOUNT.
		IF (ecLevel < dumpHist) AND (NOT canCharge) {
			IF discharge_caps(capModuleList) {
				PRINT "discharging ".// + deltaEc.
				SET dumpHist TO MIN(MAX(ecLevel - dumpRate * 2,dumpRate),dumpThreshold).
				delta_ec(ec).
			}
		}
		IF canCharge AND (ecLevel > dumpHist) {
			IF ecLevel >= chargeThreshold {
				IF charge_caps(capModuleList) { PRINT "charging". }
				delta_ec(ec).
			} ELSE {
				SET dumpHist TO MIN(ecLevel - dumpRate,dumpThreshold).
			}
		}
	}
	WAIT 0.
}

FUNCTION am_control_core {
	PARAMETER controlerList IS SHIP:PARTSTAGGED("charge_controler").
	LOCAL coreNumber IS (CORE:PART:UID + ".0"):TONUMBER().
	LOCAL isControlCore IS TRUE.
	FOR controller IN controlerList {
		IF (controller:UID + ".0"):TONUMBER() > coreNumber {
			RETURN FALSE.
		}
	}
	RETURN TRUE.
}

FUNCTION get_ec {
	FOR res IN SHIP:RESOURCES {
		IF res:NAME = "electricCharge" {
			RETURN res.
		}
	}
}

FUNCTION max_charge {
	PARAMETER modList.
	LOCAL maxCharge IS 0.
	FOR pMod IN modList { FOR res IN pMod:PART:RESOURCES {
		LOCAL res IS get_charge(pMod:PART).
		IF res:CAPACITY > maxCharge {
			SET maxCharge TO res:CAPACITY.
		}
	}}
	RETURN maxCharge.
}

FUNCTION delta_ec {
	PARAMETER ec.
	LOCAL localTime IS TIME:SECONDS.
	LOCAL newEC IS ec:AMOUNT.
	LOCAL dTime IS localTime - oldTime.
	IF dTime <> 0 {
		LOCAL dEC IS (newEC - oldEC) / dTime.
		SET oldEC TO newEC.
		SET oldTime TO localTime.
		RETURN dEC.
	} ELSE {
		SET oldEC TO newEC.
		SET oldTime TO localTime.
		RETURN 0.
	}
}

FUNCTION discharge_caps {
	PARAMETER modList.
	LOCAL canDischarge IS TRUE.
	FOR capMod IN modList {
		LOCAL capRes IS get_charge(capMod:PART).
		IF canDischarge AND capRes:AMOUNT + 1 > capRes:CAPACITY {
			capMod:DOEVENT("discharge capacitor").
			SET canDischarge TO FALSE.
		}
		have_do_event(capMod,"disable recharge").
	}
	RETURN NOT canDischarge.
}

FUNCTION charge_caps {
	PARAMETER modList.
	FOR capMod IN modList {
		//LOCAL capMod IS cap:GETMODULE("dischargeCapacitor").
		LOCAL capRes IS get_charge(capMod:PART).
		IF capRes:AMOUNT + 1 < capRes:CAPACITY {
			IF have_do_event(capMod,"enable recharge") {
				RETURN TRUE.
			}
		}
	}
	RETURN FALSE.
}

FUNCTION get_charge {
	PARAMETER par.
	FOR res IN par:RESOURCES {
		IF res:NAME = "StoredCharge" {
			RETURN res.
		}
	}
}

FUNCTION have_do_event {
	PARAMETER pMod,event.
	IF pMod:HASEVENT(event) {
		pMod:DOEVENT(event).
		RETURN TRUE.
	} ELSE {
		RETURN FALSE.
	}
}

FUNCTION not_warping {
	RETURN (KUNIVERSE:TIMEWARP:RATE = 1) AND KUNIVERSE:TIMEWARP:ISSETTLED.
}