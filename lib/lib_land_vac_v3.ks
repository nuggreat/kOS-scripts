LOCAL yRef TO v(0,1,0).
LOCAL gg0 TO CONSTANT:g0.
LOCAL zeroVec TO v(0,0,0).

FUNCTION sim_land_vac {
	PARAMETER
		vesPos,		//the initial position of the vessel
		vesVel,		//the initial velocity of the vessel, should be orbital velocity
		vesISP,		//the ISP of the vessel
		vesThrust,	//the thrust of the vessel, should be some fraction of full thrust
		vesMass,	//the initial mass of the vessel
		vesLowMass,	//the mass of the vessel with no fuel
		bodyPos,	//the position of the body
		localBody,	//the body structure around which the simulation occurs
		solarPrime,	//the solar prime vector at the time the position and velocity vectors where collected
		timeStep,	//the time step to use for simulation
		rotCorrect.	//adjust final position to account for surface rotation

	SET timeStep TO MAX(timeStep,0.02).	//making sure the time step is at least as large as one physics tick
	LOCAL halfTimeStep TO timeStep / 2.
	LOCAL sixthTimeStep TO timeStep / 6.

	LOCAL GM TO localBody:MU.			//the MU of the body the ship is in orbit of
	LOCAL angVel TO localBody:ANGULARVEL.
	LOCAL massFlow TO vesThrust / (gg0 * vesISP).
	LOCAL timeLimit TO (vesMass - vesLowMass) / massFlow.

	FUNCTION current_accel {
		PARAMETER vesPos, vesVel, bodyPos, currentTime.
		LOCAL radInVec TO bodyPos - vesPos.
		LOCAL gravAcc TO radInVec:NORMALIZED * (GM / radInVec:SQRMAGNITUDE).
		LOCAL srfRetroVel TO VCRS(radInVec, angVel) - vesVel.
		// RCS OFF.
		// WAIT UNTIL RCS.
		LOCAL currentMass TO vesMass - massFlow * currentTime.
		LOCAL engAcc TO srfRetroVel:NORMALIZED *  vesThrust / currentMass.
		RETURN gravAcc + engAcc.
	}

	//rotating all vectors into the ship solar frame prior to simulation
	LOCAL shipRawToShipSolar TO LOOKDIRUP(solarPrime, yRef).
	SET angVel TO angVel * shipRawToShipSolar.
	LOCAL vesPosSol TO vesPos * shipRawToShipSolar.
	LOCAL vesVelSol TO vesVel * shipRawToShipSolar.
	LOCAL bodyPosSolRoot TO bodyPos * shipRawToShipSolar.
	SET bodyPosSol TO bodyPosSolRoot.

	LOCAL cycles TO 0.
	LOCAL totalTime TO 0.
	LOCAL terminate TO FALSE.
	LOCAL krakenBane TO zeroVec:VEC.
	LOCAL newSurfVel TO vesVelSol - VCRS(angVel, vesPosSol - bodyPosSol).
	LOCAL oldSurfVel TO newSurfVel.
// tangent velocity for surface is the cross product of the bodies angular velocity and the vector from body to vessel
// VCRS(angVel, vesPosSol - bodyPosSol).
	UNTIL FALSE {
		//RK-4 solver
		LOCAL k1Vel TO vesVelSol.
		LOCAL k1Acc TO current_accel(vesPosSol, vesVelSol, bodyPosSol, totalTime).
		LOCAL k2Vel TO vesVelSol + k1Acc * halfTimeStep.
		LOCAL k2Acc TO current_accel(vesPosSol + k1Vel * halfTimeStep, k2Vel, bodyPosSol, totalTime + halfTimeStep).
		LOCAL k3Vel TO vesVelSol + k2Acc * halfTimeStep.
		LOCAL k3Acc TO current_accel(vesPosSol + k2Vel * halfTimeStep, k3Vel, bodyPosSol, totalTime + halfTimeStep).
		LOCAL k4Vel TO vesVelSol + k3Acc * timeStep.
		LOCAL k4Acc TO current_accel(vesPosSol + k3Vel, k4Vel, bodyPosSol, totalTime + timeStep).

		SET vesVelSol TO vesVelSol + sixthTimeStep * (k1Acc + k2Acc * 2 + k3Acc * 2 + k4Acc).
		SET vesPosSol TO vesPosSol + sixthTimeStep * (k1Vel + k2Vel * 2 + k3Vel * 2 + k4Vel).

		//state update
		SET cycles TO cycles + 1.
		SET totalTime TO totalTime + timeStep.

		//kraken's bane
		// IF vesPosSol:SQRMAGNITUDE > 36_000_000 {//equivalent to vesPosSol:MAG > 6000
			// LOCAL baneVec IS vesPosSol + vesVelSol:NORMALIZED * 3000.
			// SET vesPosSol TO vesPosSol - baneVec.
			// SET krakenBane TO krakenBane - baneVec.
			// SET bodyPosSol TO bodyPosSolRoot + baneVec.
		// }

		//termination check
		SET newSurfVel TO vesVelSol - VCRS(angVel, vesPosSol - bodyPosSol).
		IF terminate OR (VANG(oldSurfVel, newSurfVel) > 90) OR (timeLimit < totalTime) {//simulation end conditions
			BREAK.
		} ELSE {
			SET oldSurfVel TO newSurfVel.
		}

		//tweak final time step to reduce error/overshoot.
		LOCAL nextAccel TO current_accel(vesPosSol, vesVelSol, bodyPosSol, totalTime).
		LOCAL potentialStep IS newSurfVel:MAG / nextAccel:MAG.
		IF potentialStep < 1 {
			IF potentialStep > 0.02 {//sets time step such that velocity will be near or at zero at the end of the next step
				SET timeStep TO potentialStep.
				SET halfTimeStep TO timeStep / 2.
				SET sixthTimeStep TO timeStep / 6.
				SET terminate TO TRUE.//will end the loop on the next pass
			} ELSE {
				BREAK.
			}
		}
	}
	LOCAL finalMass TO vesMass - massFlow * totalTime.
	LOCAL radOutVec TO vesPosSol - bodyPosSol.
	LOCAL vesAlt TO radOutVec:MAG - localBody:RADIUS.
	IF rotCorrect {//TODO: need to verfy rotation is correct
		SET radOutVec TO radOutVec * ANGLEAXIS(totalTime / localBody:ROTATIONPERIOD * -360, angVel:NORMALIZED).
	}
	WAIT 0.
	SET shipRawToShipSolar TO LOOKDIRUP(SOLARPRIMEVECTOR, yRef).
	LOCAL pos TO localBody:POSITION - SHIP:POSITION + radOutVec * shipRawToShipSolar:INVERSE.
	RETURN LEX("pos", pos,"rad", radOutVec:MAG,"alt", vesAlt, "seconds", totalTime, "mass", finalMass, "cycles", cycles).
}