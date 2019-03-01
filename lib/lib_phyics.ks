@LAZYGLOBAL OFF.

LOCAL testFunctions IS LEX(	00,LIST(accel_time_to_dist@,time_dist_to_accel@,accel_dist_to_time@,"accel_time_to_dist"),
							01,LIST(accel_time_to_speed@,time_speed_to_accel@,accel_speed_to_time@,"accel_time_to_speed"),

							02,LIST(accel_dist_to_time@,d_t_a@,accel_time_to_dist@,"accel_dist_to_time"),
							03,LIST(accel_dist_to_speed@,dist_speed_to_accel@,accel_speed_to_dist@,"accel_dist_to_speed"),

							04,LIST(accel_speed_to_time@,s_t_a@,accel_time_to_speed@,"accel_speed_to_time"),
							05,LIST(accel_speed_to_dist@,s_d_a@,accel_dist_to_speed@,"accel_speed_to_dist"),


							06,LIST(time_dist_to_accel@,d_a_t@,t_a_d@,"accel_speed_to_dist"),
							07,LIST(time_dist_to_speed@,dist_speed_to_time@,time_speed_to_dist@,"time_dist_to_speed"),

							08,LIST(time_speed_to_accel@,s_a_t@,t_a_s@,"accel_speed_to_dist"),
							09,LIST(time_speed_to_dist@,s_d_t@,time_dist_to_speed@,"time_speed_to_dist"),

							10,LIST(dist_speed_to_time@,s_t_d@,d_t_s@,"accel_speed_to_dist"),
							11,LIST(dist_speed_to_accel@,s_a_d@,d_a_s@,"accel_speed_to_dist")).


ABORT OFF.
RCS ON.
LOCAL i IS 0.
UNTIL ABORT {
	CLEARSCREEN.
	PRINT i.
	PRINT testFunctions[i][3].
	LOCAL v1 IS ROUND(RANDOM() * 200 - 100,2).
	IF v1 = 0 { SET v1 TO 1. }
	LOCAL v2 IS ROUND(RANDOM() * 200 - 100,2).
	IF v2 = 0 { SET v2 TO 1. }
	PRINT "v1: " + v1.
	PRINT "v2: " + v2.
	LOCAL v3 IS testFunctions[i][0]:CALL(v1,v2).
	PRINT "v3: " + v3.
	LOCAL v1_t IS ROUND(testFunctions[i][1]:CALL(v2,v3),2).
	LOCAL v2_t IS ROUND(testFunctions[i][2]:CALL(v1,v3),2).
	LOCAL passed IS TRUE.
	IF NOT (v1 = v1_t){
		PRINT "  v1: " + v1.
		PRINT "v1_t: " + v1_t.
		SET passed TO FALSE.
	}
	IF NOT (v2 = v2_t) {
		PRINT "  v2: " + v2.
		PRINT "v2_t: " + v2_t.
		SET passed TO FALSE.
	}
	PRINT " ".
	IF NOT passed { RCS OFF.}
	IF i < 11 {
		SET i TO i + 1.
	} ELSE {
		SET i TO 0.
	}
	WAIT UNTIL RCS.
}
FUNCTION d_t_a {PARAMETER d,t. RETURN time_dist_to_accel(t,d).}
FUNCTION s_t_a {PARAMETER s,t. RETURN time_speed_to_accel(t,s).}
FUNCTION s_d_a {PARAMETER s,d. RETURN dist_speed_to_accel(d,s).}
FUNCTION s_d_t {PARAMETER s,d. RETURN dist_speed_to_time(d,s).}
FUNCTION d_a_t {PARAMETER d,a. RETURN accel_dist_to_time(a,d).}
FUNCTION t_a_d {PARAMETER t,a. RETURN accel_time_to_dist(a,t).}
FUNCTION s_a_t {PARAMETER s,a. RETURN accel_speed_to_time(a,s).}
FUNCTION t_a_s {PARAMETER t,a. RETURN accel_time_to_speed(a,t).}
FUNCTION s_t_d {PARAMETER s,t. RETURN time_speed_to_dist(t,s).}
FUNCTION d_t_s {PARAMETER d,t. RETURN time_dist_to_speed(t,d).}
FUNCTION s_a_d {PARAMETER s,a. RETURN accel_speed_to_dist(a,s).}
FUNCTION d_a_s {PARAMETER d,a. RETURN accel_dist_to_speed(a,d).}

FUNCTION accel_time_to_dist  { PARAMETER a,t. IF t >= 0 { RETURN 0.5 * a * t^2. } ELSE { RETURN -0.5 * a * t^2. }}
FUNCTION accel_time_to_speed { PARAMETER a,t. RETURN a * t. }

FUNCTION accel_dist_to_time  { PARAMETER a,d. IF (d * a) > 0 { RETURN SQRT(ABS(2 * d / a)). } ELSE IF (d * a) < 0 { RETURN -SQRT(ABS(2 * d / a)). } ELSE { RETURN 0. }}
FUNCTION accel_dist_to_speed { PARAMETER a,d. RETURN accel_time_to_speed(ABS(a),accel_dist_to_time(a,d)). }

FUNCTION accel_speed_to_time { PARAMETER a,s. IF a <> 0 { RETURN s / a. } ELSE { RETURN 0. }}
FUNCTION accel_speed_to_dist { PARAMETER a,s. IF a <> 0 { IF s > 0 { RETURN 0.5 * s^2 / a. } ELSE { RETURN -0.5 * s^2 / a. }} ELSE RETURN 0.}

FUNCTION time_dist_to_accel  { PARAMETER t,d. IF t > 0 { RETURN 2 * d / t^2. } ELSE IF t < 0 { RETURN -2 * d / t^2. } ELSE { RETURN 0. }}
FUNCTION time_dist_to_speed  { PARAMETER t,d. IF t <> 0 {RETURN d / t. } ELSE { RETURN 0. }}

FUNCTION time_speed_to_accel { PARAMETER t,s. IF t <> 0 { RETURN s / t. } ELSE { RETURN 0. }}
FUNCTION time_speed_to_dist  { PARAMETER t,s. RETURN s * t. }

FUNCTION dist_speed_to_time  { PARAMETER d,s. IF s <> 0 { RETURN d / s. } ELSE { RETURN 0. }}
FUNCTION dist_speed_to_accel { PARAMETER d,s. IF s <> 0 { IF (d / s) >= 0 { RETURN ABS(0.5 * d / (d / s)^2). } ELSE { RETURN -ABS(0.5 * d / (d / s)^2). }} ELSE { RETURN 0. }}