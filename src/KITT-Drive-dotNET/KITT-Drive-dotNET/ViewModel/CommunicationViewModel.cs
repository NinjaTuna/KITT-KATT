﻿using System;
using System.Collections.Generic;
using System.IO.Ports;
using System.Linq;
using System.Text;
using System.Windows;
using System.Windows.Input;

namespace KITT_Drive_dotNET.ViewModel
{
	public class CommunicationViewModel : ObservableObject
	{
		#region Properties
		private Communication _communication = new Communication();

		public Communication Communication
		{
			get { return _communication; }
			set { _communication = value; }
		}

		public string[] SerialPorts { get { return SerialPort.GetPortNames(); } }

		public object SelectedSerialPort { get; set; }
		public string ConnectButtonString
		{
			get
			{
				if (Communication.SerialPort.IsOpen)
					return "Disconnect";
				else
					return "Connect";
			}
		}

		public bool CanSelectSerialPort
		{
			get
			{
				if (Communication.SerialPort.IsOpen)
					return false;
				else
					return true;
			}
		}
		#endregion

		#region Commands
		void ConnectExecute()
		{
			if (!Communication.SerialPort.IsOpen)
			{
				//Connect
				Communication.SerialPort.PortName = (string)SelectedSerialPort;

				if (Communication.OpenPort() != 0)
					MessageBox.Show(Communication.LastError, "Could not open port", MessageBoxButton.OK, MessageBoxImage.Error);
			}
			else
			{
				//Disconnect
				Communication.SerialPort.Close();
				RaisePropertyChanged("SerialPorts");
			}

			RaisePropertyChanged("ConnectButtonString");
			RaisePropertyChanged("CanSelectSerialPort");
		}

		bool CanConnectExecute()
		{
			string port = (string)SelectedSerialPort;
			if ((!Communication.SerialPort.IsOpen && !String.IsNullOrEmpty(port) && port.Substring(0, 3) == "COM") || Communication.SerialPort.IsOpen)
				return true;

			return false;
		}

		public ICommand Connect { get { return new RelayCommand(ConnectExecute, CanConnectExecute); } }
		#endregion	
	}
}
