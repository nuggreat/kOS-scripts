@LAZYGLOBAL OFF.

FUNCTION accel_time_to_dist  { PARAMETER a,t. IF t >= 0 { RETURN 0.5 * a * t^2. } ELSE { RETURN -0.5 * a * t^2. }}
FUNCTION accel_time_to_speed { PARAMETER a,t. RETURN a * t. }

FUNCTION accel_dist_to_time  { PARAMETER a,d. IF (d * a) > 0 { RETURN SQRT(ABS(2 * d / a)). } ELSE IF (d * a) < 0 { RETURN -SQRT(ABS(2 * d / a)). } ELSE { RETURN 0. }}
FUNCTION accel_dist_to_speed { PARAMETER a,d. IF (d * a) > 0 { RETURN SQRT(ABS(2 * d * a)). } ELSE IF (d * a) < 0 { RETURN -SQRT(ABS(2 * d * a)). } ELSE { RETURN 0. }}

FUNCTION accel_speed_to_time { PARAMETER a,s. IF a <> 0 { RETURN s / a. } ELSE { RETURN 0. }}
FUNCTION accel_speed_to_dist { PARAMETER a,s. IF a <> 0 { IF s > 0 { RETURN 0.5 * s^2 / a. } ELSE { RETURN -0.5 * s^2 / a. }} ELSE RETURN 0.}

FUNCTION time_dist_to_accel  { PARAMETER t,d. IF t > 0 { RETURN 2 * d / t^2. } ELSE IF t < 0 { RETURN -2 * d / t^2. } ELSE { RETURN 0. }}
FUNCTION time_dist_to_speed  { PARAMETER t,d. IF t <> 0 {RETURN d / t. } ELSE { RETURN 0. }}

FUNCTION time_speed_to_accel { PARAMETER t,s. IF t <> 0 { RETURN s / t. } ELSE { RETURN 0. }}
FUNCTION time_speed_to_dist  { PARAMETER t,s. RETURN s * t. }

FUNCTION dist_speed_to_time  { PARAMETER d,s. IF s <> 0 { RETURN d / s. } ELSE { RETURN 0. }}
FUNCTION dist_speed_to_accel { PARAMETER d,s. IF d <> 0 { IF s >= 0 { RETURN ABS(0.5 * s^2 / d). } ELSE { RETURN -ABS(0.5 * s^2 / d). } } ELSE { RETURN 0. }}



