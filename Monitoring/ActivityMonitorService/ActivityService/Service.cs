using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Timers;

namespace ActivityService
{
    public class Service
    {
        private static int TestsStarted = 0;
        private static int TestsDone = 0;
        private static DateTime ServiceStarted = DateTime.Now;
        private static DateTime LastTestStarted = DateTime.Now;
        private static DateTime LastTestDone = DateTime.Now;

        private readonly System.Timers.Timer _timer;
        private Thread _thread;

        private static TcpListener Listener;

        // INPUT PARAMETERS
        private static string IpAddress = "0.0.0.0";
        private static int PortNumber = 5050;
        private static long SnoozeTime = 10 * 60 * 1000;
        private static long TimerStep = 60 * 1000;
        private static string OutputFilePath = "C:\\Users\\Public\\";
        private static string FileName = "ActivityService_Log_" + DateTime.Now.ToString("yyyyMMddHHmmssfff") + ".txt";

        public Service(string ipAddress, int port, string output, long snooze, long timerStep)
        {
            IpAddress = ipAddress;
            PortNumber = port;
            SnoozeTime = snooze;
            TimerStep = timerStep;
            OutputFilePath = output + FileName;

            if (File.Exists(OutputFilePath + FileName)) File.Delete(OutputFilePath + FileName);
            Listener = new TcpListener(IPAddress.Parse(IpAddress), PortNumber);

            _timer = new System.Timers.Timer(TimerStep) { AutoReset = true };
            _timer.Elapsed += TimerElapsed;

            _thread = new Thread(Run);
        }

        public Service()
        {
            if (File.Exists(OutputFilePath + FileName)) File.Delete(OutputFilePath + FileName);
            Listener = new TcpListener(IPAddress.Parse(IpAddress), PortNumber);

            _timer = new System.Timers.Timer(TimerStep) { AutoReset = true };
            _timer.Elapsed += TimerElapsed;

            _thread = new Thread(Run);
        }

        

        public void Start()
        {
            Listener.Start();
            _timer.Start();
            _thread.Start();
            WriteDebug("Service started");
            WriteDebug("Listening to " + IpAddress + ":" + PortNumber);
        }

        public void Stop()
        {
            _thread.Abort();
            _timer.Stop();
            Listener.Stop();
            WriteDebug("Service stoped");
        }

        private void DecodeMessage(string message)
        {

        }





        private static void Run()
        {
            while (true)
            {
                TcpClient client = Listener.AcceptTcpClient();
                NetworkStream nwStream = client.GetStream();
                byte[] buffer = new byte[client.ReceiveBufferSize];

                int bytesRead = nwStream.Read(buffer, 0, client.ReceiveBufferSize);

                string dataReceived = Encoding.ASCII.GetString(buffer, 0, bytesRead);
                WriteDebug("\nReceived message: " + dataReceived + "\n");
                dynamic data = JsonConvert.DeserializeObject(dataReceived);
                switch (data.state.ToString())
                {
                    case "start":
                        {
                            TestsStarted++;
                            LastTestStarted = DateTime.Now;
                            break;
                        }
                    case "stop":
                        {
                            TestsDone++;
                            LastTestDone = DateTime.Now;
                            break;
                        }
                    default:
                        {
                            WriteDebug("ERROR - WRONG TEST STATE");
                            break;
                        }
                }

                WriteDebug("Message received: hostname " + data.host.ToString() + ", time " + data.timestamp.ToString() + ", state " + data.state.ToString());
                client.Close();
            }
        }

        private static void TimerElapsed(object sender, ElapsedEventArgs e)
        {
            WriteDebug(TestsStarted + " tests started, " +
                TestsDone + " tests done, " +
                (TestsStarted - TestsDone) + " tests active, " +
                LastTestStarted + " last test started, " +
                LastTestDone + " last test done");
            if (TestsStarted - TestsDone < 0)
            {
                WriteDebug("ERROR - More done tests than started ?!?! (PROBABLY ERROR IN RECEIVING MESSAGES FROM WORKERS)");
            }
            else
            {
                if (TestsStarted - TestsDone == 0)
                {
                    WriteDebug("0 active tests since " +
                        LastTestDone + "! Windows will shut down in: " +
                        Math.Round((LastTestDone.Subtract(DateTime.Now).TotalMilliseconds + SnoozeTime) / 1000 / 60, 0).ToString() + " minutes");
                    if (LastTestDone.Subtract(DateTime.Now).TotalMilliseconds + SnoozeTime < 0)
                    {
                        WriteDebug("Windows is shutting down!");
                        //Process.Start("shutdown", "/s /t 0"); // LINE FOR SHUTTING DOWN WINDOWS
                    }
                }
            }
        }

        static ReaderWriterLock locker = new ReaderWriterLock();
        public static void WriteDebug(string text)
        {
            try
            {
                locker.AcquireWriterLock(int.MaxValue);
                System.IO.File.AppendAllLines(OutputFilePath + FileName, new[] { DateTime.Now + " - " + text });
                Console.WriteLine(DateTime.Now + " - " + text);
            }
            finally
            {
                locker.ReleaseWriterLock();
            }
        }
    }
}
