@LAZYGLOBAL OFF.

FUNCTION accel_time_to_dist	{ PARAMETER accel,time.	RETURN 1/2 * accel * time^2. }
FUNCTION accel_time_to_speed	{ PARAMETER accel,time.	RETURN accel * time. }

FUNCTION accel_dist_to_time	{ PARAMETER accel,dist.	RETURN sqrt(2 * dist / accel). }
FUNCTION accel_dist_to_speed	{ PARAMETER accel,dist.	RETURN accel_time_to_speed(accel,accel_dist_to_time(accel,dist)). }

FUNCTION accel_speed_to_time	{ PARAMETER accel,speed.	RETURN speed / accel. }
FUNCTION accel_speed_to_dist	{ PARAMETER accel,speed.	RETURN accel_time_to_dist(accel,accel_speed_to_time(accel,speed)). }

FUNCTION time_dist_to_accel	{ PARAMETER time,dist.	RETURN 2 * dist / time^2. }
FUNCTION time_dist_to_speed	{ PARAMETER time,dist.	RETURN accel_time_to_speed(time_dist_to_accel(time,dist),time). }

FUNCTION time_speed_to_accel	{ PARAMETER time,speed.	RETURN speed / time. }
FUNCTION time_speed_to_dist	{ PARAMETER time,speed.	RETURN accel_time_to_dist(time_speed_to_accel(time,speed),time). }

FUNCTION dist_speed_to_time	{ PARAMETER dist,speed.	RETURN dist / speed. }
FUNCTION dist_speed_to_accel	{ PARAMETER dist,speed.	RETURN time_dist_to_accel(dist_speed_to_time(dist,speed),dist). }