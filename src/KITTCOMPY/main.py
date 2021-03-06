from kitt import *
from tools import *
import numpy as np
import time
import os

kitt = KITTSerial()
print "Connecting to KITT..."
while not kitt.connect():
	print "Could not connect, retrying..."

model = StateSpaceModel()
lp_filter = LowPassFilter(10, 0.3)
unr_filter = UnrealisticValueFilter(2)

dists_left = [0]
dists_right = [0]
states = [[[0],[0]]]
start_sample_time = time.time()
start_time = time.time()

ref_time = [0,   5,   5.1, 10 ]
ref_sig =  [0.5, 0.5, 1.5, 1.5]
drive_limit = 0.15
time_max = 20
time_init = 20
control = False

while True:
	if time.time()-start_time >= time_max:
		break

	status = kitt.status()

	# Apply unrealistic value filter
	dist_left = unr_filter.eval(dists_left, status.distanceLeft)
	dist_right = unr_filter.eval(dists_right, status.distanceRight)

	# Apply low pass filter
	dist_left = lp_filter.eval(dists_left, dist_left)
	dist_right = lp_filter.eval(dists_right, dist_right)

	dists_left.append(dist_left)
	dists_right.append(dist_right)

	# if dist_left < dist_right:
	dist = dist_left
	# else:
	# 	dist = dist_right

	# Time calculation
	dt = time.time()-start_sample_time
	start_sample_time = time.time()
	cur_time = time.time()-start_time

	# Find reference
	ref = np.interp(cur_time, ref_time, ref_sig)

	
	if control == False and cur_time >= time_init:
		control = True

	# State-space calculation
	cur_state = np.matrix(states[-1])
	cur_slope = model.slope(cur_state, ref, dist, control=control) 			# Current slope
	pred_state = cur_state + dt*cur_slope 									# Predicted state
	pred_slope = model.slope(pred_state, ref, dist, control=control) 		# Predicted slope
	cur_state = cur_state + dt/2*(cur_slope + pred_slope)					# New current state
	states.append(cur_state.tolist()) 					
	drive = model.output(cur_state, ref, control=control)					# Model output

	# Limit drive signal
	if drive > drive_limit:
		drive = drive_limit

	if drive < -drive_limit:
		drive = -drive_limit

	os.system('clear')
	print "KITTCOMPY"
	print "-------------"
	print "Time:                " + str(round(cur_time,2)) + "s / " + str(round(time_max,2)) + "s"
	print "Current sample time: " + str(round(dt*1000,2)) + "ms"
	print
	if control == True:
		print "Mode:                control"
	else:
		print "Mode:                init"
	print 
	print "Distance left:       " + str(round(dist_left,2)) + "m" + str(status.distanceLeft)
	print "Distance right:      " + str(round(dist_right,2)) + "m"
	print
	print "Distance:            " + str(round(dist,2)) + "m"
	print "Goal:                " + str(round(ref,2)) + "m"
	print "Drive:               " + str(round(drive,3))
	print
	print "Internal state 1:    " + str(round(cur_state.tolist()[0][0],2))
	print "Internal state 2:    " + str(round(cur_state.tolist()[1][0],2))
	print
	print "Battery voltage:     " + str(round(status.batteryVoltage,2))	+ "V"

	kitt.drive(drive)
