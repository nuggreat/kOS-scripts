FUNCTION sim_land_spot {//credit to dunbaratu for the orignal code
PARAMETER
ves,
isp,			//the isp of the active engines
t_delta,			//time step for sim
cruse.			//a cruse time with no thrust in seconds

LOCAL t_delta IS MAX(t_delta,0.02).	//making it so the t_delta can't go below 0.02s
LOCAL GM IS ves:BODY:MU.				//the MU of the body the ship is in orbit of
LOCAL b_pos IS ves:BODY:POSITION.	//the position of the body relitave to the ship
LOCAL t_max IS ves:AVAILABLETHRUST * 0.975.	//the thrust available to the ship
LOCAL m IS ves:MASS.					//the ship's mass
LOCAL vel IS ves:VELOCITY:SURFACE.	//the ship's velocity relitave to thesurface
LOCAL prev_vel IS vel.
LOCAL deltaM IS t_max / (9.806 * isp) * t_delta.

LOCAL pos IS V(0,0,0).
LOCAL t IS 0.
LOCAL cycles IS 0.

IF cruse > 0 {
UNTIL t >= cruse {	//advancses the simulation of the craft with out burning for the amount of time defined by cruse
	SET cycles TO cycles + 1.
	LOCAL up_vec IS (pos - b_pos).

//	LOCAL up_unit IS up_vec:NORMALIZED.
//	LOCAL r_square IS up_vec:SQRMAGNITUDE.
//	LOCAL localGrav IS GM / r_square.
//	LOCAL a_vec IS - up_unit * localGrav.
	LOCAL a_vec IS - up_vec:NORMALIZED * (GM / up_vec:SQRMAGNITUDE).
	// above comented math is merged to save on IPU during the sim

	SET prev_vel TO vel.
	SET vel TO vel + a_vec * t_delta.

	LOCAL avg_vel IS 0.5 * (vel + prev_vel).

	SET pos TO pos + avg_vel * t_delta.

	SET t TO t + t_delta.
}
}

UNTIL FALSE {	//retroburn simulation
	SET cycles TO cycles + 1.
	LOCAL up_vec IS (pos - b_pos).

	IF VDOT(vel, prev_vel) < 0 { break. }	//ends sim when velosity reverses

//	LOCAL up_unit IS up_vec:NORMALIZED.
//	LOCAL r_square IS up_vec:SQRMAGNITUDE.
//	LOCAL localGrav IS GM / r_square.
//	LOCAL eng_a_vec IS (t_max / m) * (- vel:NORMALIZED).
//	LOCAL a_vec IS eng_a_vec - up_unit*localGrav.
	LOCAL a_vec IS ((t_max / m) * (- vel:NORMALIZED)) - ((GM / up_vec:SQRMAGNITUDE) * up_vec:NORMALIZED).
	// above comented math is merged to save on IPU during the sim

	SET prev_vel TO vel.
	SET vel TO vel + a_vec * t_delta.

	LOCAL avg_vel is 0.5 * (vel+prev_vel).

	SET pos TO pos + (avg_vel * t_delta).
	SET m TO m - deltaM.

	IF m <= 0 { BREAK. }
	SET t TO t + t_delta.
}

RETURN LEX("pos", pos,"vel", vel,"seconds", t,"mass", m,"cycles", cycles).
}