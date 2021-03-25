using System;
using Topshelf;

namespace ActivityService
{
    class Program
    {
        static string ipAddress = null;
        static int port;
        static string output;
        static int snooze;
        static int timerStep;
        static string outputFile;
        static void Main(string[] args)
        {
            var exitCode = HostFactory.Run(x => 
            {
                //x.AddCommandLineDefinition("ipAdress", f => { ipAddress = f; });
                //x.ApplyCommandLine();

                x.Service<Service>(s =>
                {
                    //if (args.Length > 0)
                    //    s.ConstructUsing(service => new Service(ipAddress, port, output, snooze, timerStep));
                    /*else*/ s.ConstructUsing(service => new Service());
                    s.WhenStarted(service => service.Start());
                    s.WhenStopped(service => service.Stop());
                });

                x.RunAsLocalSystem();

                x.SetServiceName("ActivityMonitorService");
                x.SetDisplayName("Activity Monitor Service");
                x.SetDescription("Checks if there are connections to this machine. If there are no connections machine will turn off");
            });

            int exitCodeValue = (int)Convert.ChangeType(exitCode, exitCode.GetTypeCode());
            Environment.ExitCode = exitCodeValue;
        }
    }
}
