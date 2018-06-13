// A library of functions to calculate navball-based directions:

// This file is distributed under the terms of the MIT license, (c) the KSLib team

// compass_for returns curent heading of ship (number renge    0 to 360)
// pitch_for   returns curent pitch of ship   (number range  -90 to 90)
// roll_for    returns curent roll of ship    (number range -180 to 180)

@lazyglobal off.

function east_for {
	parameter ves.

	return vcrs(ves:up:vector, ves:north:vector).
}

function compass_for {
	parameter ves.

	local pointing is ves:facing:forevector.
	local east is east_for(ves).

	local trig_x is vdot(ves:north:vector, pointing).
	local trig_y is vdot(east, pointing).

	local result is arctan2(trig_y, trig_x).

	if result < 0 {
		return 360 + result.
	} else {
		return result.
	}
}

function pitch_for {
	parameter ves.

	return 90 - vang(ves:up:vector, ves:facing:forevector).
}

function roll_for {
	parameter ves.

	if vang(ship:facing:vector,ship:up:vector) < 0.2 { //this is the dead zone for roll when the ship is vertical
		return 0.
	} else {
		local raw is vang(vxcl(ship:facing:vector,ship:up:vector), ves:facing:starvector).
		if vang(ves:up:vector, ves:facing:topvector) > 90 {
			if raw > 90 {
				return 270 - raw.
			} else {
				return -90 - raw.
			}
		} else {
			return raw - 90.
		}
	}
}