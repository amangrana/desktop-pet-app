using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Windows.Forms;

internal static class WindowsFullscreenHelperLiveTest
{
    private const string ProtocolPrefix = "DPF1";
    private const int TimeoutMilliseconds = 5000;
    private const int GwlExStyle = -20;
    private const long WsExTopmost = 0x00000008L;

    [STAThread]
    private static int Main(string[] args)
    {
        if (
            args.Length == 2
            && args[0] == "--probe"
            && File.Exists(args[1])
        )
        {
            return RunAnonymousProbe(args[1]);
        }
        if (args.Length != 1 || !File.Exists(args[0]))
        {
            Console.Error.WriteLine("Fullscreen helper path is missing.");
            return 2;
        }

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        string token = Guid.NewGuid().ToString("N");
        Process helper = null;

        using (UdpClient socket = new UdpClient(
            new IPEndPoint(IPAddress.Loopback, 0)
        ))
        using (Form pet = CreatePetWindow())
        using (Form candidate = CreateCandidateWindow())
        {
            try
            {
                pet.Show();
                candidate.WindowState = FormWindowState.Maximized;
                candidate.Show();
                candidate.Activate();
                Application.DoEvents();

                int port = ((IPEndPoint)socket.Client.LocalEndPoint).Port;
                helper = Process.Start(new ProcessStartInfo
                {
                    FileName = args[0],
                    Arguments = String.Format(
                        "--port {0} --token {1} --parent-pid {2} "
                            + "--pet-window-handle {3}",
                        port,
                        token,
                        Process.GetCurrentProcess().Id,
                        pet.Handle.ToInt64()
                    ),
                    UseShellExecute = false,
                    CreateNoWindow = true
                });
                if (helper == null)
                {
                    return Fail("the production helper did not start");
                }

                ProtocolState protocol = new ProtocolState(socket, token);
                if (!WaitUntil(protocol, delegate
                    { return protocol.Ready && protocol.LastState == false; }))
                {
                    return Fail(
                        "an ordinary maximized window was treated as fullscreen"
                    );
                }

                candidate.WindowState = FormWindowState.Normal;
                candidate.FormBorderStyle = FormBorderStyle.None;
                candidate.Bounds = Screen.FromControl(candidate).Bounds;
                candidate.Activate();
                if (!WaitForState(protocol, true))
                {
                    return Fail("a real borderless fullscreen window was missed");
                }
                PumpFor(protocol, 200);
                if (IsNativeTopmost(pet.Handle))
                {
                    return Fail("fullscreen did not lower the native pet window");
                }

                int falseReportsBeforeOverlay = protocol.FalseReports;
                using (Form overlay = new Form())
                {
                    overlay.Text = "Desktop Pet fullscreen test overlay";
                    overlay.StartPosition = FormStartPosition.Manual;
                    overlay.Bounds = new Rectangle(300, 180, 480, 220);
                    overlay.Show(candidate);
                    overlay.Activate();
                    PumpFor(protocol, 1800);
                    if (
                        protocol.LastState != true
                        || protocol.FalseReports != falseReportsBeforeOverlay
                    )
                    {
                        return Fail(
                            "a fullscreen-owned overlay caused topmost flicker"
                        );
                    }
                    overlay.Close();
                }
                candidate.Activate();

                int falseReportsBeforeTransition = protocol.FalseReports;
                candidate.FormBorderStyle = FormBorderStyle.Sizable;
                PumpFor(protocol, 700);
                candidate.FormBorderStyle = FormBorderStyle.None;
                candidate.Bounds = Screen.FromControl(candidate).Bounds;
                candidate.Activate();
                PumpFor(protocol, 800);
                if (
                    protocol.LastState != true
                    || protocol.FalseReports != falseReportsBeforeTransition
                )
                {
                    return Fail(
                        "a transient fullscreen style change caused flicker"
                    );
                }

                candidate.FormBorderStyle = FormBorderStyle.Sizable;
                candidate.Bounds = new Rectangle(160, 120, 900, 650);
                candidate.Activate();
                if (!WaitForState(protocol, false))
                {
                    return Fail("leaving fullscreen did not restore normal state");
                }
                if (!EnforceTopmost(args[0], pet.Handle))
                {
                    return Fail(
                        "the one-shot helper did not restore native topmost"
                    );
                }

                candidate.WindowState = FormWindowState.Maximized;
                candidate.Activate();
                if (!RemainsInactive(protocol, 1300))
                {
                    return Fail(
                        "maximizing after fullscreen reactivated fullscreen state"
                    );
                }

                Console.WriteLine(
                    "Windows fullscreen helper live geometry self-test passed."
                );
                return 0;
            }
            finally
            {
                if (helper != null && !helper.HasExited)
                {
                    helper.Kill();
                    helper.WaitForExit(2000);
                }
            }
        }
    }

    private static int RunAnonymousProbe(string helperPath)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        string token = Guid.NewGuid().ToString("N");
        Process helper = null;
        using (UdpClient socket = new UdpClient(
            new IPEndPoint(IPAddress.Loopback, 0)
        ))
        using (Form pet = CreatePetWindow())
        {
            try
            {
                pet.Show();
                pet.Activate();
                Application.DoEvents();
                int port = ((IPEndPoint)socket.Client.LocalEndPoint).Port;
                helper = Process.Start(new ProcessStartInfo
                {
                    FileName = helperPath,
                    Arguments = String.Format(
                        "--port {0} --token {1} --parent-pid {2} "
                            + "--pet-window-handle {3}",
                        port,
                        token,
                        Process.GetCurrentProcess().Id,
                        pet.Handle.ToInt64()
                    ),
                    UseShellExecute = false,
                    CreateNoWindow = true
                });
                if (helper == null)
                {
                    return Fail("the anonymous probe helper did not start");
                }

                ProtocolState protocol = new ProtocolState(socket, token);
                bool? lastPrintedState = null;
                Stopwatch timer = Stopwatch.StartNew();
                Console.WriteLine("PROBE_READY");
                while (timer.ElapsedMilliseconds < 20000)
                {
                    Application.DoEvents();
                    protocol.Pump();
                    if (
                        protocol.LastState.HasValue
                        && protocol.LastState != lastPrintedState
                    )
                    {
                        Console.WriteLine(
                            "STATE "
                                + (protocol.LastState.Value ? "1" : "0")
                        );
                        lastPrintedState = protocol.LastState;
                    }
                    Thread.Sleep(20);
                }
                return 0;
            }
            finally
            {
                if (helper != null && !helper.HasExited)
                {
                    helper.Kill();
                    helper.WaitForExit(2000);
                }
            }
        }
    }

    private static Form CreatePetWindow()
    {
        return new Form
        {
            Text = "Desktop Pet fullscreen test pet",
            StartPosition = FormStartPosition.Manual,
            Bounds = new Rectangle(40, 40, 180, 180),
            TopMost = true,
            ShowInTaskbar = false
        };
    }

    private static bool EnforceTopmost(string helperPath, IntPtr petWindow)
    {
        using (Process restore = Process.Start(new ProcessStartInfo
        {
            FileName = helperPath,
            Arguments = String.Format(
                "--set-z-order topmost --pet-window-handle {0}",
                petWindow.ToInt64()
            ),
            UseShellExecute = false,
            CreateNoWindow = true
        }))
        {
            if (restore == null || !restore.WaitForExit(2000))
            {
                return false;
            }
            Application.DoEvents();
            Thread.Sleep(100);
            return restore.ExitCode == 0 && IsNativeTopmost(petWindow);
        }
    }

    private static bool IsNativeTopmost(IntPtr window)
    {
        return (
            GetWindowLongPtr(window, GwlExStyle).ToInt64() & WsExTopmost
        ) != 0;
    }

    private static Form CreateCandidateWindow()
    {
        return new Form
        {
            Text = "Desktop Pet fullscreen test candidate",
            StartPosition = FormStartPosition.Manual,
            Bounds = new Rectangle(160, 120, 900, 650),
            FormBorderStyle = FormBorderStyle.Sizable
        };
    }

    private static bool WaitForState(ProtocolState protocol, bool expected)
    {
        return WaitUntil(protocol, delegate
            { return protocol.LastState == expected; });
    }

    private static bool WaitUntil(
        ProtocolState protocol,
        Func<bool> condition
    )
    {
        Stopwatch timer = Stopwatch.StartNew();
        while (timer.ElapsedMilliseconds < TimeoutMilliseconds)
        {
            Application.DoEvents();
            protocol.Pump();
            if (condition())
            {
                return true;
            }
            Thread.Sleep(20);
        }
        return false;
    }

    private static bool RemainsInactive(
        ProtocolState protocol,
        int durationMilliseconds
    )
    {
        Stopwatch timer = Stopwatch.StartNew();
        while (timer.ElapsedMilliseconds < durationMilliseconds)
        {
            Application.DoEvents();
            protocol.Pump();
            if (protocol.LastState != false)
            {
                return false;
            }
            Thread.Sleep(20);
        }
        return true;
    }

    private static void PumpFor(
        ProtocolState protocol,
        int durationMilliseconds
    )
    {
        Stopwatch timer = Stopwatch.StartNew();
        while (timer.ElapsedMilliseconds < durationMilliseconds)
        {
            Application.DoEvents();
            protocol.Pump();
            Thread.Sleep(20);
        }
    }

    private static int Fail(string message)
    {
        Console.Error.WriteLine(
            "Windows fullscreen helper live test failed: " + message
        );
        return 1;
    }

    private sealed class ProtocolState
    {
        private readonly UdpClient socket;
        private readonly string token;

        public bool Ready { get; private set; }
        public bool? LastState { get; private set; }
        public int FalseReports { get; private set; }

        public ProtocolState(UdpClient udpSocket, string sessionToken)
        {
            socket = udpSocket;
            token = sessionToken;
        }

        public void Pump()
        {
            while (socket.Available > 0)
            {
                IPEndPoint sender = new IPEndPoint(IPAddress.Any, 0);
                byte[] bytes = socket.Receive(ref sender);
                string packet = Encoding.ASCII.GetString(bytes);
                string prefix = ProtocolPrefix + "|" + token + "|";
                if (!packet.StartsWith(prefix, StringComparison.Ordinal))
                {
                    continue;
                }
                string payload = packet.Substring(prefix.Length);
                if (payload == "READY")
                {
                    Ready = true;
                }
                else if (payload == "STATE|0")
                {
                    LastState = false;
                    FalseReports++;
                }
                else if (payload == "STATE|1")
                {
                    LastState = true;
                }
            }
        }
    }

    [System.Runtime.InteropServices.DllImport(
        "user32.dll",
        EntryPoint = "GetWindowLongPtrW"
    )]
    private static extern IntPtr GetWindowLongPtr(
        IntPtr window,
        int index
    );
}
