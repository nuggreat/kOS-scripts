@LAZYGLOBAL OFF.

FUNCTION accel_time_to_dist  { PARAMETER a,t. IF t > 0 { RETURN 0.5 * a * t^2. } ELSE { RETURN -0.5 * a * t^2. }}
FUNCTION accel_time_to_speed { PARAMETER a,t. RETURN a * t. }

FUNCTION accel_dist_to_time  { PARAMETER a,d. IF a = 0 { RETURN 0. } ELSE { IF d < 0 { RETURN -sqrt(2 * ABS(d) / a). } ELSE { RETURN sqrt(2 * ABS(d) / a). }}}
FUNCTION accel_dist_to_speed { PARAMETER a,d. RETURN accel_time_to_speed(a,accel_dist_to_time(a,d)). }

FUNCTION accel_speed_to_time { PARAMETER a,s. IF a = 0 { RETURN 0. } ELSE { RETURN s / a. }}
FUNCTION accel_speed_to_dist { PARAMETER a,s. RETURN accel_time_to_dist(a,accel_speed_to_time(a,s)). }

FUNCTION time_dist_to_accel  { PARAMETER t,d. IF t > 0 { RETURN 2 * d / t^2. } ELSE IF t < 0 { RETURN -2 * d / t^2. } ELSE { RETURN 0. }}
FUNCTION time_dist_to_speed  { PARAMETER t,d. RETURN accel_time_to_speed(time_dist_to_accel(t,d),t). }

FUNCTION time_speed_to_accel { PARAMETER t,s. IF t = 0 { RETURN 0. } ELSE { RETURN s / t. }}
FUNCTION time_speed_to_dist  { PARAMETER t,s. RETURN accel_time_to_dist(time_speed_to_accel(t,s),t). }

FUNCTION dist_speed_to_time  { PARAMETER d,s. IF s = 0 { RETURN 0. } ELSE { RETURN d / s. }}
FUNCTION dist_speed_to_accel { PARAMETER d,s. RETURN time_dist_to_accel(dist_speed_to_time(d,s),d). }