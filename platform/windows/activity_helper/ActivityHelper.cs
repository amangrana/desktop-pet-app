using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;

internal static class ActivityHelper
{
    private const uint WM_DESTROY = 0x0002;
    private const uint WM_CLOSE = 0x0010;
    private const uint WM_INPUT = 0x00FF;
    private const uint WM_TIMER = 0x0113;
    private const uint RID_INPUT = 0x10000003;
    private const uint RIM_TYPEMOUSE = 0;
    private const uint RIM_TYPEKEYBOARD = 1;
    private const uint RIDEV_INPUTSINK = 0x00000100;
    private const ushort RI_KEY_BREAK = 0x0001;
    private const ushort RI_MOUSE_LEFT_BUTTON_DOWN = 0x0001;
    private const ushort RI_MOUSE_RIGHT_BUTTON_DOWN = 0x0004;
    private const ushort RI_MOUSE_MIDDLE_BUTTON_DOWN = 0x0010;
    private const ushort RI_MOUSE_BUTTON_4_DOWN = 0x0040;
    private const ushort RI_MOUSE_BUTTON_5_DOWN = 0x0100;
    private const int ERROR_CLASS_ALREADY_EXISTS = 1410;
    private const int FLUSH_INTERVAL_MS = 100;
    private static readonly IntPtr HWND_MESSAGE = new IntPtr(-3);

    private static readonly WindowProcedure WindowProcedureDelegate =
        HandleWindowMessage;

    private static ActivitySender sender;
    private static IntPtr messageWindow;
    private static int parentProcessId;
    private static int parentCheckTicks;

    private static int Main(string[] args)
    {
        Dictionary<string, string> options = ParseArguments(args);
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

        parentProcessId = parentPid;

        try
        {
            sender = new ActivitySender(port, token);

            if (options.ContainsKey("--test-batch"))
            {
                sender.SendReady();
                sender.SendBatch(12, 3);
                sender.Dispose();
                return 0;
            }

            int result = RunMessageWindow();
            sender.Dispose();
            return result;
        }
        catch
        {
            if (sender != null)
            {
                sender.SendError("initialization_failed");
                sender.Dispose();
            }
            return 3;
        }
    }

    private static int RunMessageWindow()
    {
        IntPtr module = GetModuleHandle(null);
        string className = "DesktopPetActivityHelper_" + Process.GetCurrentProcess().Id;
        WNDCLASSEX windowClass = new WNDCLASSEX();
        windowClass.cbSize = (uint)Marshal.SizeOf(typeof(WNDCLASSEX));
        windowClass.lpfnWndProc = WindowProcedureDelegate;
        windowClass.hInstance = module;
        windowClass.lpszClassName = className;

        ushort classAtom = RegisterClassEx(ref windowClass);
        if (classAtom == 0 && Marshal.GetLastWin32Error() != ERROR_CLASS_ALREADY_EXISTS)
        {
            sender.SendError("window_registration_failed");
            return 4;
        }

        messageWindow = CreateWindowEx(
            0,
            className,
            "Desktop Pet Activity Helper",
            0,
            0,
            0,
            0,
            0,
            HWND_MESSAGE,
            IntPtr.Zero,
            module,
            IntPtr.Zero
        );
        if (messageWindow == IntPtr.Zero)
        {
            sender.SendError("message_window_failed");
            return 5;
        }

        RAWINPUTDEVICE[] devices = new RAWINPUTDEVICE[2];
        devices[0].usagePage = 0x01;
        devices[0].usage = 0x02;
        devices[0].flags = RIDEV_INPUTSINK;
        devices[0].target = messageWindow;
        devices[1].usagePage = 0x01;
        devices[1].usage = 0x06;
        devices[1].flags = RIDEV_INPUTSINK;
        devices[1].target = messageWindow;

        if (!RegisterRawInputDevices(
            devices,
            (uint)devices.Length,
            (uint)Marshal.SizeOf(typeof(RAWINPUTDEVICE))
        ))
        {
            sender.SendError(
                "raw_input_registration_failed_"
                + Marshal.GetLastWin32Error().ToString()
            );
            DestroyWindow(messageWindow);
            return 6;
        }

        if (SetTimer(messageWindow, new UIntPtr(1), FLUSH_INTERVAL_MS, IntPtr.Zero)
            == UIntPtr.Zero)
        {
            sender.SendError("timer_failed");
            DestroyWindow(messageWindow);
            return 7;
        }

        sender.SendReady();

        MSG message;
        int messageResult;
        while ((messageResult = GetMessage(
            out message,
            IntPtr.Zero,
            0,
            0
        )) > 0)
        {
            TranslateMessage(ref message);
            DispatchMessage(ref message);
        }

        return messageResult == -1 ? 8 : 0;
    }

    private static IntPtr HandleWindowMessage(
        IntPtr window,
        uint message,
        IntPtr wParam,
        IntPtr lParam
    )
    {
        if (message == WM_INPUT)
        {
            CountRawInput(lParam);
        }
        else if (message == WM_TIMER)
        {
            sender.Flush();
            parentCheckTicks++;
            if (parentCheckTicks >= 10)
            {
                parentCheckTicks = 0;
                if (!IsParentRunning())
                {
                    PostMessage(window, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
                }
            }
            return IntPtr.Zero;
        }
        else if (message == WM_CLOSE)
        {
            DestroyWindow(window);
            return IntPtr.Zero;
        }
        else if (message == WM_DESTROY)
        {
            sender.Flush();
            PostQuitMessage(0);
            return IntPtr.Zero;
        }

        return DefWindowProc(window, message, wParam, lParam);
    }

    private static void CountRawInput(IntPtr rawInputHandle)
    {
        uint size = 0;
        uint headerSize = (uint)Marshal.SizeOf(typeof(RAWINPUTHEADER));
        if (GetRawInputData(
            rawInputHandle,
            RID_INPUT,
            IntPtr.Zero,
            ref size,
            headerSize
        ) == UInt32.MaxValue || size < headerSize)
        {
            return;
        }

        IntPtr buffer = Marshal.AllocHGlobal((int)size);
        try
        {
            uint copied = GetRawInputData(
                rawInputHandle,
                RID_INPUT,
                buffer,
                ref size,
                headerSize
            );
            if (copied == UInt32.MaxValue || copied < headerSize)
            {
                return;
            }

            uint inputType = unchecked((uint)Marshal.ReadInt32(buffer, 0));
            IntPtr data = IntPtr.Add(buffer, (int)headerSize);

            if (inputType == RIM_TYPEKEYBOARD)
            {
                // RAWKEYBOARD.Flags is at byte offset 2. We deliberately do
                // not read MakeCode, VKey, Message, or text information.
                ushort flags = unchecked((ushort)Marshal.ReadInt16(data, 2));
                if ((flags & RI_KEY_BREAK) == 0)
                {
                    sender.AddKeyboardPress();
                }
            }
            else if (inputType == RIM_TYPEMOUSE)
            {
                // RAWMOUSE.usButtonFlags is at byte offset 4. Coordinates,
                // movement, wheel data, and the specific button identity are
                // never sent or retained.
                ushort buttonFlags =
                    unchecked((ushort)Marshal.ReadInt16(data, 4));
                int presses = 0;
                presses += HasFlag(buttonFlags, RI_MOUSE_LEFT_BUTTON_DOWN);
                presses += HasFlag(buttonFlags, RI_MOUSE_RIGHT_BUTTON_DOWN);
                presses += HasFlag(buttonFlags, RI_MOUSE_MIDDLE_BUTTON_DOWN);
                presses += HasFlag(buttonFlags, RI_MOUSE_BUTTON_4_DOWN);
                presses += HasFlag(buttonFlags, RI_MOUSE_BUTTON_5_DOWN);
                sender.AddMousePresses(presses);
            }
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }

    private static int HasFlag(ushort value, ushort flag)
    {
        return (value & flag) != 0 ? 1 : 0;
    }

    private static bool IsParentRunning()
    {
        try
        {
            using (Process parent = Process.GetProcessById(parentProcessId))
            {
                return !parent.HasExited;
            }
        }
        catch
        {
            return false;
        }
    }

    private static Dictionary<string, string> ParseArguments(string[] args)
    {
        Dictionary<string, string> options =
            new Dictionary<string, string>(StringComparer.Ordinal);
        for (int index = 0; index < args.Length; index++)
        {
            string argument = args[index];
            if (argument == "--test-batch")
            {
                options[argument] = "true";
                continue;
            }

            if (argument.StartsWith("--", StringComparison.Ordinal)
                && index + 1 < args.Length)
            {
                options[argument] = args[++index];
            }
        }
        return options;
    }

    private static bool TryGetInteger(
        Dictionary<string, string> options,
        string name,
        out int value
    )
    {
        string raw;
        if (!options.TryGetValue(name, out raw))
        {
            value = 0;
            return false;
        }
        return Int32.TryParse(raw, out value);
    }

    private sealed class ActivitySender : IDisposable
    {
        private readonly UdpClient client;
        private readonly string prefix;
        private int keyboardPending;
        private int mousePending;

        internal ActivitySender(int port, string token)
        {
            client = new UdpClient();
            client.Connect(IPAddress.Loopback, port);
            prefix = "DPA1|" + token + "|";
        }

        internal void AddKeyboardPress()
        {
            keyboardPending++;
        }

        internal void AddMousePresses(int count)
        {
            if (count > 0)
            {
                mousePending += count;
            }
        }

        internal void Flush()
        {
            int keyboard = keyboardPending;
            int mouse = mousePending;
            keyboardPending = 0;
            mousePending = 0;
            if (keyboard > 0 || mouse > 0)
            {
                SendBatch(keyboard, mouse);
            }
        }

        internal void SendReady()
        {
            Send("READY");
        }

        internal void SendBatch(int keyboard, int mouse)
        {
            Send(
                "BATCH|"
                + keyboard.ToString()
                + "|"
                + mouse.ToString()
            );
        }

        internal void SendError(string code)
        {
            Send("ERROR|" + code);
        }

        private void Send(string payload)
        {
            try
            {
                byte[] bytes = Encoding.ASCII.GetBytes(prefix + payload);
                client.Send(bytes, bytes.Length);
            }
            catch
            {
                // A closed local receiver means the parent is stopping.
            }
        }

        public void Dispose()
        {
            client.Close();
        }
    }

    private delegate IntPtr WindowProcedure(
        IntPtr window,
        uint message,
        IntPtr wParam,
        IntPtr lParam
    );

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct WNDCLASSEX
    {
        internal uint cbSize;
        internal uint style;
        internal WindowProcedure lpfnWndProc;
        internal int cbClsExtra;
        internal int cbWndExtra;
        internal IntPtr hInstance;
        internal IntPtr hIcon;
        internal IntPtr hCursor;
        internal IntPtr hbrBackground;
        internal string lpszMenuName;
        internal string lpszClassName;
        internal IntPtr hIconSm;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RAWINPUTDEVICE
    {
        internal ushort usagePage;
        internal ushort usage;
        internal uint flags;
        internal IntPtr target;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RAWINPUTHEADER
    {
        internal uint type;
        internal uint size;
        internal IntPtr device;
        internal IntPtr wParam;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        internal int x;
        internal int y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MSG
    {
        internal IntPtr window;
        internal uint message;
        internal IntPtr wParam;
        internal IntPtr lParam;
        internal uint time;
        internal POINT point;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr GetModuleHandle(string moduleName);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern ushort RegisterClassEx(ref WNDCLASSEX windowClass);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateWindowEx(
        uint extendedStyle,
        string className,
        string windowName,
        uint style,
        int x,
        int y,
        int width,
        int height,
        IntPtr parent,
        IntPtr menu,
        IntPtr instance,
        IntPtr parameter
    );

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyWindow(IntPtr window);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterRawInputDevices(
        RAWINPUTDEVICE[] devices,
        uint deviceCount,
        uint deviceSize
    );

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetRawInputData(
        IntPtr rawInput,
        uint command,
        IntPtr data,
        ref uint size,
        uint headerSize
    );

    [DllImport("user32.dll")]
    private static extern IntPtr DefWindowProc(
        IntPtr window,
        uint message,
        IntPtr wParam,
        IntPtr lParam
    );

    [DllImport("user32.dll", SetLastError = true)]
    private static extern UIntPtr SetTimer(
        IntPtr window,
        UIntPtr timerId,
        uint interval,
        IntPtr callback
    );

    [DllImport("user32.dll")]
    private static extern int GetMessage(
        out MSG message,
        IntPtr window,
        uint minimum,
        uint maximum
    );

    [DllImport("user32.dll")]
    private static extern bool TranslateMessage(ref MSG message);

    [DllImport("user32.dll")]
    private static extern IntPtr DispatchMessage(ref MSG message);

    [DllImport("user32.dll")]
    private static extern void PostQuitMessage(int exitCode);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool PostMessage(
        IntPtr window,
        uint message,
        IntPtr wParam,
        IntPtr lParam
    );
}
