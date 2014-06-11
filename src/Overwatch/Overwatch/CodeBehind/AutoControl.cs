﻿using Overwatch.ViewModel;
using System;
using System.Collections.Generic;
using System.Timers;

namespace Overwatch
{
	public enum AutoControlMode{Reality, SystemSimulation, LocalisationSimulation};

	/// <summary>
	/// Holds all required data and methods to enable autonomous control of the vehicle via MATLAB.
	/// Also handles the connection with MATLAB for the exchange of data.
	/// </summary>
	public class AutoControl
	{
		#region Data members
		public Matlab Matlab { get; set; }
		public Vehicle Vehicle { get { return Data.MainViewModel.VehicleViewModel.Vehicle; } }
		public ViewModel.VehicleViewModel VehicleViewModel { get { return Data.MainViewModel.VehicleViewModel; } }
		public List<Waypoint> QueuedWaypoints { get; protected set; }
		public List<Waypoint> VisitedWaypoints { get; protected set; }
		public Waypoint CurrentWayPoint
		{
			get
			{
				if (QueuedWaypoints.Count > 0)
					return QueuedWaypoints[0];
				else
					return null;
			}
		}

		public bool ObservationEnabled { get; set; }
		public bool ControlEnabled { get; set; }
		//public string Mode { get; set; }
		public AutoControlMode Mode { get; set; }

		// State variables
		bool localiseFinished = false;
		bool statusReceived = false;

		Timer simTimer;
		#endregion

		#region Construction
		/// <summary>
		/// Constructs a default instance of the AutoControl class.
		/// </summary>
		public AutoControl()
		{
			// Disable by default
			ObservationEnabled = false;
			// Initialise MATLAB
			Matlab = new Matlab();
			Matlab.Hide();
			// Initialise some other stuff
			QueuedWaypoints = new List<Waypoint>();
			VisitedWaypoints = new List<Waypoint>();
			// Subscribe to status updates
			Data.MainViewModel.CommunicationViewModel.Communication.StatusReceived += Communication_StatusReceived;
		}
		#endregion

		#region Methods
		/// <summary>
		/// Toggles observation of the vehicle.
		/// </summary>
		/// <returns>True if observation is enabled, false if disabled.</returns>
		public bool ToggleObservation()
		{
			// Flip the switch
			ObservationEnabled = !ObservationEnabled;

			// Hide or show MATLAB
			if (ObservationEnabled)
			{
				Matlab.Show();
				MatlabDoInitialise();
			}
			else
			{
				Matlab.Hide();

				if (simTimer != null && simTimer.Enabled)
					simTimer.Stop();
			}

			return ObservationEnabled;
		}

		/// <summary>
		/// Toggles autonomous control of the vehicle.
		/// </summary>
		/// <returns>True if autocontrol is enabled, false if disabled.</returns>
		public void ToggleControl()
		{
			// Flip the switch
			ControlEnabled = !ControlEnabled;
		}

		/// <summary>
		/// Initialise MATLAB to the correct directory and run the initialisation script.
		/// </summary>
		public void MatlabDoInitialise()
		{
			object o;

			// Get scripts location and try to change MATLAB's directory to it
			string loc = Data.SrcDirectory + "\\Overwatch-MATLAB";
			try
			{
				Matlab.Instance.Feval("cd", 0, out o, loc);
			}
			catch (Exception exc)
			{
				System.Diagnostics.Debug.WriteLine(exc.ToString());
			}

			if (Mode == AutoControlMode.SystemSimulation)
			{
				Matlab.PutVariable("PaWavSim", 0);
				Matlab.PutVariable("TDOASim", 1);
				Vehicle.SensorDistanceLeft = 3;
				Vehicle.SensorDistanceRight = 3;
			}
			else if (Mode == AutoControlMode.LocalisationSimulation)
			{
				Matlab.PutVariable("PaWavSim", 1);
				Matlab.PutVariable("TDOASim", 0);
				Vehicle.SensorDistanceLeft = 3;
				Vehicle.SensorDistanceRight = 3;
			}			

			// Run the init.m script
			o = null; // Has to be reset for some reason
			try
			{
				Matlab.Instance.Feval("generate", 0, out o);
				o = null;
				Matlab.Instance.Feval("init", 0, out o);
			}
			catch (Exception exc)
			{
				System.Diagnostics.Debug.WriteLine(exc.ToString());
			}

			if (Mode == AutoControlMode.SystemSimulation || Mode == AutoControlMode.LocalisationSimulation)
			{
				simTimer = new Timer();
				simTimer.Interval = 100;
				simTimer.Elapsed += simTimer_Elapsed;

				if (Mode == AutoControlMode.SystemSimulation)
					MatlabDoSimulate();
				else
					MatlabDoLocalise();	
			}
			else
				MatlabDoLocalise();
		}

		public void MatlabDoLocalise()
		{
			if (Mode == AutoControlMode.Reality)
				Data.MainViewModel.CommunicationViewModel.Communication.RequestStatus();
			else
				statusReceived = true;

			// Perform localisation in MATLAB
			object o; // Useless, but required
			try
			{
				Matlab.Instance.Feval("loopLocalize", 0, out o);
			}
			catch (Exception exc)
			{
				System.Diagnostics.Debug.WriteLine(exc.ToString());
			}

			// If status is received, do control, else, set flag and pause execution
			if (statusReceived)
				MatlabDoControl();
			else
				localiseFinished = true;
		}

		public void MatlabDoControl()
		{
			// Stop control and observation if no more waypoints in queue
			if (CurrentWayPoint == null)
			{
				Data.MainViewModel.AutoControlViewModel.Toggle();
				return;
			}

			// Reset states
			localiseFinished = false;
			statusReceived = false;

			// Feed MATLAB our new data
			Matlab.PutVariable("sensor_l", "global", Vehicle.SensorDistanceLeft);
			Matlab.PutVariable("sensor_r", "global", Vehicle.SensorDistanceRight);
			Matlab.PutVariable("battery", "global", Vehicle.BatteryVoltage);
			Matlab.PutVariable("waypoint", "global", CurrentWayPoint != null ? new double[] { CurrentWayPoint.X * Data.FieldSize, CurrentWayPoint.Y * Data.FieldSize } : new double[] { });

			// Run control function in MATLAB
			object o;
			try
			{
				Matlab.Instance.Feval("loopControl", 0, out o);
			}
			catch (Exception exc)
			{
				System.Diagnostics.Debug.WriteLine(exc.ToString());
			}

			// Get relevant newly calculated data from MATLAB
			VehicleViewModel.X = (double)Matlab.GetVariable("loc_x", "global") / Data.FieldSize;
			VehicleViewModel.Y = (double)Matlab.GetVariable("loc_y", "global") / Data.FieldSize;
			VehicleViewModel.Angle = (double)Matlab.GetVariable("angle", "global") / Math.PI * 180;
			Vehicle.Velocity = (double)Matlab.GetVariable("speed", "global");
			int PWMSteer = (int)((double)Matlab.GetVariable("pwm_steer", "global"));
			int PWMDrive = (int)((double)Matlab.GetVariable("pwm_drive", "global"));

			// Command KITT if necessary
			if (Mode == AutoControlMode.Reality && ControlEnabled)
				Data.MainViewModel.CommunicationViewModel.Communication.DoDrive(PWMSteer, PWMDrive);

			if (Mode == AutoControlMode.Reality)
			{
				// Advance to the next waypoint if current is reached
				double d = Math.Sqrt(Math.Pow(VehicleViewModel.X - CurrentWayPoint.X, 2) + Math.Pow(VehicleViewModel.Y - CurrentWayPoint.Y, 2));
				if (d * Data.FieldSize < 0.2)
					Data.MainViewModel.VisualisationViewModel.FinishWaypointViewModel();
			}

			if (Mode == AutoControlMode.LocalisationSimulation)
				simTimer.Start();
		}

		public void MatlabDoSimulate()
		{
			if (!ObservationEnabled)
			{
				simTimer.Stop();
				return;
			}

			// Stop control and observation if no more waypoints in queue
			if (CurrentWayPoint == null)
			{
				Data.MainViewModel.AutoControlViewModel.Toggle();
				return;
			}

			// Feed MATLAB relevant data
			Matlab.PutVariable("battery", "global", Vehicle.BatteryVoltage);
			Matlab.PutVariable("waypoint", "global", CurrentWayPoint != null ? new double[] { CurrentWayPoint.X * Data.FieldSize, CurrentWayPoint.Y * Data.FieldSize } : new double[] { });

			// Run control function in MATLAB
			object o;
			try
			{
				Matlab.Instance.Feval("loopSimulate", 0, out o);
			}
			catch (Exception exc)
			{
				System.Diagnostics.Debug.WriteLine(exc.ToString());
			}

			// Get relevant newly calculated data from MATLAB
			VehicleViewModel.X = (double)Matlab.GetVariable("loc_x", "global") / Data.FieldSize;
			VehicleViewModel.Y = (double)Matlab.GetVariable("loc_y", "global") / Data.FieldSize;
			VehicleViewModel.Angle = (double)Matlab.GetVariable("angle", "global") / Math.PI * 180;
			Vehicle.Velocity = (double)Matlab.GetVariable("speed", "global");

			// Advance to the next waypoint if current is reached
			double d = Math.Sqrt(Math.Pow(VehicleViewModel.X - CurrentWayPoint.X, 2) + Math.Pow(VehicleViewModel.Y - CurrentWayPoint.Y, 2));
			if (d * Data.FieldSize < 0.2)
				Data.MainViewModel.VisualisationViewModel.FinishWaypointViewModel();

			// Advance to next iteration
			simTimer.Start();
		}

		/// <summary>
		/// Create a new waypoint at the given location, along with a corresponding ViewModel and notify MATLAB.
		/// </summary>
		/// <param name="x">The position of the waypoint on the X-axis.</param>
		/// <param name="y">The position of the waypoint on the Y-axis.</param>
		/// <returns>The newly created WaypointViewModel.</returns>
		public void AddWaypoint(Waypoint w)
		{
			// Add Waypoint to the list
			QueuedWaypoints.Add(w);
		}

		/// <summary>
		/// Remove the given waypoint.
		/// </summary>
		/// <param name="w">The waypoint to remove.</param>
		public void RemoveWaypoint(Waypoint w)
		{
			// Remove the waypoint from the correct list
			if (!w.Visited)
				QueuedWaypoints.Remove(w);
			else
				VisitedWaypoints.Remove(w);
		}

		/// <summary>
		/// Mark a waypoint as finished by moving it from the queue to the visited list.
		/// </summary>
		/// <param name="w">The waypoint to mark as finished.</param>
		public void FinishWaypoint(Waypoint w)
		{
			QueuedWaypoints.Remove(w);
			VisitedWaypoints.Add(w);
		}

		/// <summary>
		/// Mark a waypoint as no longer finished by moving it from the visited list back into the queue.
		/// </summary>
		/// <param name="w">The waypoint to mark as no longer finished.</param>
		public void UnFinishWaypoint(Waypoint w)
		{
			VisitedWaypoints.Remove(w);
			QueuedWaypoints.Add(w);
		}

		/// <summary>
		/// Swap two waypoints in the queue.
		/// </summary>
		/// <param name="index1">The index of the first waypoint two sap.</param>
		/// <param name="index2">The index of the second waypoint to swap.</param>
		public void SwapWaypoints(int index1, int index2)
		{
			Waypoint tmp = QueuedWaypoints[index1];
			QueuedWaypoints[index1] = QueuedWaypoints[index2];
			QueuedWaypoints[index2] = tmp;
		}
		#endregion

		#region Event handling
		/// <summary>
		/// Performs the required actions whenever a new status update is received from the vehicle.
		/// </summary>
		/// <param name="sender"></param>
		/// <param name="e"></param>
		void Communication_StatusReceived(object sender, EventArgs e)
		{
			// If localisation is already finished, do control, else, set flag and pause execution
			if (localiseFinished)
				MatlabDoControl();
			else
				statusReceived = true;
		}

		void simTimer_Elapsed(object sender, ElapsedEventArgs e)
		{
			simTimer.Stop();
			if (Mode == AutoControlMode.SystemSimulation)
				MatlabDoSimulate();
			else if (Mode == AutoControlMode.LocalisationSimulation)
				MatlabDoLocalise();
		}
		#endregion
	}
}
