using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

internal static class FullscreenHelper
{
    private const string ProtocolPrefix = "DPF1";
    private const int PollIntervalMilliseconds = 500;
    private const int ZOrderSettleMilliseconds = 100;
    private const int ExitConfirmationPolls = 3;
    private const int EdgeTolerancePixels = 2;
    private const uint MonitorDefaultToNearest = 0x00000002;
    private const uint GaRoot = 2;
    private const uint GaRootOwner = 3;
    private const uint GwHwndNext = 2;
    private const int DwmwaCloaked = 14;
    private const int GwlStyle = -16;
    private const int GwlExStyle = -20;
    private const long WsDlgFrame = 0x00400000L;
    private const long WsThickFrame = 0x00040000L;
    private const long WsExWindowEdge = 0x00000100L;
    private const long WsExToolWindow = 0x00000080L;
    private const int QunsRunningD3dFullscreen = 3;
    private const uint SwpNoSize = 0x0001;
    private const uint SwpNoMove = 0x0002;
    private const uint SwpNoActivate = 0x0010;
    private const uint SwpNoOwnerZOrder = 0x0200;
    private const uint SwpNoSendChanging = 0x0400;
    private const uint SwpAsyncWindowPos = 0x4000;
    private static readonly IntPtr HwndTopmost = new IntPtr(-1);
    private static readonly IntPtr HwndBottom = new IntPtr(1);

    private static int Main(string[] args)
    {
        Dictionary<string, string> options = ParseArguments(args);
        int zOrderExitCode;
        if (TryRunZOrderCommand(options, out zOrderExitCode))
        {
            return zOrderExitCode;
        }
        int port;
        int parentPid;
        string token;

        if (!TryGetInteger(options, "--port", out port)
            || port < 1
            || port > 65535
            || !TryGetInteger(options, "--parent-pid", out parentPid)
            || parentPid < 1
            || !options.TryGetValue("--token", out token)
            || String.IsNullOrWhiteSpace(token)
            || token.IndexOf('|') >= 0)
        {
            return 2;
        }

        FullscreenSender sender = null;
        try
        {
            sender = new FullscreenSender(port, token);
            sender.SendReady();

            int testState;
            if (TryGetInteger(options, "--test-state", out testState))
            {
                sender.SendState(testState != 0);
                sender.Dispose();
                return 0;
            }

            long rawPetWindow;
            if (!TryGetLong(options, "--pet-window-handle", out rawPetWindow)
                || rawPetWindow == 0)
            {
                sender.SendError("invalid_pet_window");
                sender.Dispose();
                return 3;
            }

            IntPtr petWindow = new IntPtr(rawPetWindow);
            bool hasPreviousState = false;
            bool previousState = false;
            int inactivePolls = 0;
            IntPtr activeFullscreenWindow = IntPtr.Zero;
            while (IsParentRunning(parentPid))
            {
                bool detectedFullscreen = IsExternalFullscreenOnPetMonitor(
                    petWindow,
                    ref activeFullscreenWindow
                );
                if (detectedFullscreen)
                {
                    inactivePolls = 0;
                }
                else if (hasPreviousState && previousState)
                {
                    inactivePolls++;
                }
                else
                {
                    inactivePolls = ExitConfirmationPolls;
                }
                bool fullscreen = detectedFullscreen
                    || (
                        hasPreviousState
                        && previousState
                        && inactivePolls < ExitConfirmationPolls
                    );
                if (!hasPreviousState || fullscreen != previousState)
                {
                    sender.SendState(fullscreen);
                    previousState = fullscreen;
                    hasPreviousState = true;
                }
                if (!fullscreen)
                {
                    activeFullscreenWindow = IntPtr.Zero;
                }
                if (fullscreen)
                {
                    // Removing WS_EX_TOPMOST alone does not guarantee that an
                    // already-frontmost transparent window moves behind the
                    // foreground fullscreen window. Lower the pet without
                    // activating either window, then repeat once after Godot
                    // has had time to apply its matching state change.
                    LowerPetWindow(petWindow);
                    Thread.Sleep(ZOrderSettleMilliseconds);
                    LowerPetWindow(petWindow);
                    Thread.Sleep(
                        PollIntervalMilliseconds - ZOrderSettleMilliseconds
                    );
                }
                else
                {
                    Thread.Sleep(PollIntervalMilliseconds);
                }
            }

            sender.Dispose();
            return 0;
        }
        catch
        {
            if (sender != null)
            {
                sender.SendError("detection_failed");
                sender.Dispose();
            }
            return 4;
        }
    }

    private static bool IsExternalFullscreenOnPetMonitor(
        IntPtr petWindow,
        ref IntPtr activeFullscreenWindow
    )
    {
        if (!IsWindow(petWindow))
        {
            activeFullscreenWindow = IntPtr.Zero;
            return false;
        }

        IntPtr petMonitor = MonitorFromWindow(
            petWindow,
            MonitorDefaultToNearest
        );
        if (petMonitor == IntPtr.Zero)
        {
            activeFullscreenWindow = IntPtr.Zero;
            return false;
        }

        MONITORINFO monitorInfo = new MONITORINFO();
        monitorInfo.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
        if (!GetMonitorInfo(petMonitor, ref monitorInfo))
        {
            activeFullscreenWindow = IntPtr.Zero;
            return false;
        }

        IntPtr foreground = GetForegroundWindow();
        if (foreground == IntPtr.Zero)
        {
            activeFullscreenWindow = IntPtr.Zero;
            return false;
        }
        foreground = GetAncestor(foreground, GaRoot);
        if (foreground != petWindow)
        {
            bool foregroundIsFullscreen = IsFullscreenCandidate(
                foreground,
                monitorInfo.rcMonitor
            );
            if (foregroundIsFullscreen)
            {
                activeFullscreenWindow = foreground;
                return true;
            }

            // Browser fullscreen bubbles, media controls, volume overlays and
            // owned dialogs can briefly become the foreground HWND while the
            // original fullscreen window remains visible underneath. Keep the
            // confirmed candidate in that case instead of reporting an exit.
            if (
                activeFullscreenWindow != IntPtr.Zero
                && IsFullscreenCandidate(
                    activeFullscreenWindow,
                    monitorInfo.rcMonitor
                )
                && IsOverlayOverFullscreen(
                    foreground,
                    activeFullscreenWindow,
                    monitorInfo.rcMonitor
                )
            )
            {
                return true;
            }

            activeFullscreenWindow = IntPtr.Zero;
            return false;
        }

        // Lowering a still-active pet with SWP_NOACTIVATE does not necessarily
        // change GetForegroundWindow. Keep validating the fullscreen window
        // that caused the lowering even though it is now above, rather than
        // alternating between "behind pet" and "in front of pet" each poll.
        if (
            activeFullscreenWindow != IntPtr.Zero
            && IsFullscreenCandidate(
                activeFullscreenWindow,
                monitorInfo.rcMonitor
            )
        )
        {
            return true;
        }
        // A topmost pet may briefly become the foreground window during startup
        // or interaction. Walk only the windows behind it so an already visible
        // fullscreen app still suppresses topmost without inspecting identities.
        IntPtr candidate = GetWindow(petWindow, GwHwndNext);
        int inspected = 0;
        while (candidate != IntPtr.Zero && inspected < 64)
        {
            IntPtr root = GetAncestor(candidate, GaRoot);
            if (root != IntPtr.Zero
                && root != petWindow
                && IsFullscreenCandidate(root, monitorInfo.rcMonitor))
            {
                activeFullscreenWindow = root;
                return true;
            }
            candidate = GetWindow(candidate, GwHwndNext);
            inspected++;
        }
        return false;
    }

    private static void LowerPetWindow(IntPtr petWindow)
    {
        if (!IsWindow(petWindow))
        {
            return;
        }
        SetWindowPos(
            petWindow,
            HwndBottom,
            0,
            0,
            0,
            0,
            SwpNoSize
                | SwpNoMove
                | SwpNoActivate
                | SwpNoOwnerZOrder
                | SwpNoSendChanging
                | SwpAsyncWindowPos
        );
    }

    private static void RaisePetWindow(IntPtr petWindow)
    {
        if (!IsWindow(petWindow))
        {
            return;
        }
        SetWindowPos(
            petWindow,
            HwndTopmost,
            0,
            0,
            0,
            0,
            SwpNoSize
                | SwpNoMove
                | SwpNoActivate
                | SwpNoOwnerZOrder
                | SwpNoSendChanging
                | SwpAsyncWindowPos
        );
    }

    private static bool TryRunZOrderCommand(
        Dictionary<string, string> options,
        out int exitCode
    )
    {
        exitCode = 0;
        string command;
        if (!options.TryGetValue("--set-z-order", out command))
        {
            return false;
        }

        long rawPetWindow;
        if (
            !TryGetLong(options, "--pet-window-handle", out rawPetWindow)
            || rawPetWindow == 0
        )
        {
            exitCode = 5;
            return true;
        }

        IntPtr petWindow = new IntPtr(rawPetWindow);
        if (!IsWindow(petWindow))
        {
            exitCode = 6;
            return true;
        }
        if (command == "topmost")
        {
            RaisePetWindow(petWindow);
            return true;
        }
        if (command == "bottom")
        {
            LowerPetWindow(petWindow);
            return true;
        }
        exitCode = 7;
        return true;
    }

    private static bool IsFullscreenCandidate(
        IntPtr window,
        RECT monitorBounds
    )
    {
        if (window == IntPtr.Zero
            || window == GetShellWindow()
            || window == GetDesktopWindow()
            || IsDesktopHost(window)
            || !IsWindowVisible(window)
            || IsIconic(window)
            || IsWindowCloaked(window))
        {
            return false;
        }

        RECT windowBounds;
        if (!GetWindowRect(window, out windowBounds))
        {
            return false;
        }

        bool matchesMonitor = (
            Math.Abs(windowBounds.Left - monitorBounds.Left)
                <= EdgeTolerancePixels
            && Math.Abs(windowBounds.Top - monitorBounds.Top)
                <= EdgeTolerancePixels
            && Math.Abs(windowBounds.Right - monitorBounds.Right)
                <= EdgeTolerancePixels
            && Math.Abs(windowBounds.Bottom - monitorBounds.Bottom)
                <= EdgeTolerancePixels
        );
        bool overlapsMonitor = (
            windowBounds.Left < monitorBounds.Right
            && windowBounds.Right > monitorBounds.Left
            && windowBounds.Top < monitorBounds.Bottom
            && windowBounds.Bottom > monitorBounds.Top
        );
        if (!matchesMonitor)
        {
            // Exclusive Direct3D games can use a display mode whose reported
            // HWND bounds differ from the desktop monitor rectangle. The Shell
            // exposes a dedicated state for that case; unlike QUNS_BUSY, this
            // does not classify ordinary browser video playback as fullscreen.
            return overlapsMonitor && IsExclusiveD3DFullscreen();
        }

        // Match Chromium's own Windows fullscreen-window criteria: a window
        // covering the monitor is not fullscreen while it still owns normal
        // resizable/dialog frames or extended window/tool edges. This remains
        // stable for browser video playback, whose client area may already
        // occupy a maximized window before entering element fullscreen.
        long style = GetWindowLongPtr(window, GwlStyle).ToInt64();
        long extendedStyle = GetWindowLongPtr(window, GwlExStyle).ToInt64();
        return (
            (style & (WsDlgFrame | WsThickFrame)) == 0
            && (extendedStyle & (WsExWindowEdge | WsExToolWindow)) == 0
        );
    }

    private static bool IsOverlayOverFullscreen(
        IntPtr foreground,
        IntPtr fullscreenWindow,
        RECT monitorBounds
    )
    {
        if (GetAncestor(foreground, GaRootOwner) == fullscreenWindow)
        {
            return true;
        }

        RECT overlayBounds;
        if (!GetWindowRect(foreground, out overlayBounds))
        {
            return false;
        }
        long overlayWidth = Math.Max(
            0L,
            (long)overlayBounds.Right - overlayBounds.Left
        );
        long overlayHeight = Math.Max(
            0L,
            (long)overlayBounds.Bottom - overlayBounds.Top
        );
        long monitorWidth = Math.Max(
            1L,
            (long)monitorBounds.Right - monitorBounds.Left
        );
        long monitorHeight = Math.Max(
            1L,
            (long)monitorBounds.Bottom - monitorBounds.Top
        );
        return overlayWidth * overlayHeight
            < (monitorWidth * monitorHeight) / 2L;
    }

    private static bool IsExclusiveD3DFullscreen()
    {
        int state;
        return SHQueryUserNotificationState(out state) == 0
            && state == QunsRunningD3dFullscreen;
    }

    private static bool IsDesktopHost(IntPtr window)
    {
        StringBuilder className = new StringBuilder(32);
        if (GetClassName(window, className, className.Capacity) <= 0)
        {
            return false;
        }
        string value = className.ToString();
        return value == "Progman" || value == "WorkerW";
    }

    private static bool IsWindowCloaked(IntPtr window)
    {
        int cloaked;
        int result = DwmGetWindowAttribute(
            window,
            DwmwaCloaked,
            out cloaked,
            sizeof(int)
        );
        return result == 0 && cloaked != 0;
    }

    private static bool IsParentRunning(int parentPid)
    {
        try
        {
            Process parent = Process.GetProcessById(parentPid);
            return !parent.HasExited;
        }
        catch
        {
            return false;
        }
    }

    private static Dictionary<string, string> ParseArguments(string[] args)
    {
        Dictionary<string, string> result = new Dictionary<string, string>();
        for (int index = 0; index + 1 < args.Length; index += 2)
        {
            result[args[index]] = args[index + 1];
        }
        return result;
    }

    private static bool TryGetInteger(
        Dictionary<string, string> options,
        string name,
        out int value
    )
    {
        string rawValue;
        value = 0;
        return options.TryGetValue(name, out rawValue)
            && Int32.TryParse(
                rawValue,
                NumberStyles.Integer,
                CultureInfo.InvariantCulture,
                out value
            );
    }

    private static bool TryGetLong(
        Dictionary<string, string> options,
        string name,
        out long value
    )
    {
        string rawValue;
        value = 0;
        return options.TryGetValue(name, out rawValue)
            && Int64.TryParse(
                rawValue,
                NumberStyles.Integer,
                CultureInfo.InvariantCulture,
                out value
            );
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MONITORINFO
    {
        public int cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;
    }

    private sealed class FullscreenSender : IDisposable
    {
        private readonly UdpClient client;
        private readonly string token;

        public FullscreenSender(int port, string sessionToken)
        {
            token = sessionToken;
            client = new UdpClient();
            client.Connect(IPAddress.Loopback, port);
        }

        public void SendReady()
        {
            Send("READY");
        }

        public void SendState(bool fullscreen)
        {
            Send("STATE|" + (fullscreen ? "1" : "0"));
        }

        public void SendError(string code)
        {
            Send("ERROR|" + code);
        }

        private void Send(string payload)
        {
            byte[] bytes = Encoding.ASCII.GetBytes(
                ProtocolPrefix + "|" + token + "|" + payload
            );
            client.Send(bytes, bytes.Length);
        }

        public void Dispose()
        {
            client.Close();
        }
    }

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern IntPtr GetAncestor(IntPtr window, uint flags);

    [DllImport("user32.dll")]
    private static extern IntPtr GetWindow(IntPtr window, uint command);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(
        IntPtr window,
        StringBuilder className,
        int maximumCount
    );

    [DllImport("user32.dll")]
    private static extern bool IsWindow(IntPtr window);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr window);

    [DllImport("user32.dll")]
    private static extern bool IsIconic(IntPtr window);

    [DllImport("user32.dll")]
    private static extern IntPtr GetShellWindow();

    [DllImport("user32.dll")]
    private static extern IntPtr GetDesktopWindow();

    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr window, out RECT bounds);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    private static extern IntPtr GetWindowLongPtr(
        IntPtr window,
        int index
    );

    [DllImport("user32.dll")]
    private static extern bool SetWindowPos(
        IntPtr window,
        IntPtr insertAfter,
        int x,
        int y,
        int width,
        int height,
        uint flags
    );

    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern bool GetMonitorInfo(
        IntPtr monitor,
        ref MONITORINFO monitorInfo
    );

    [DllImport("dwmapi.dll")]
    private static extern int DwmGetWindowAttribute(
        IntPtr window,
        int attribute,
        out int value,
        int valueSize
    );

    [DllImport("shell32.dll")]
    private static extern int SHQueryUserNotificationState(out int state);
}
