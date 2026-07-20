using System;
using System.Globalization;
using System.Runtime.InteropServices;

internal static class TaskbarHelper
{
    private const int S_OK = 0;

    [STAThread]
    private static int Main(string[] args)
    {
        if (args.Length != 2 || args[0] != "--delete-tab")
        {
            return 2;
        }

        long rawHandle;
        if (!Int64.TryParse(
            args[1],
            NumberStyles.Integer,
            CultureInfo.InvariantCulture,
            out rawHandle
        ) || rawHandle == 0)
        {
            return 3;
        }

        IntPtr window = new IntPtr(rawHandle);
        if (!IsWindow(window))
        {
            return 4;
        }

        ITaskbarList taskbar = null;
        try
        {
            taskbar = (ITaskbarList)new TaskbarList();
            int initializeResult = taskbar.HrInit();
            if (initializeResult != S_OK)
            {
                return 5;
            }

            int deleteResult = taskbar.DeleteTab(window);
            return deleteResult == S_OK ? 0 : 6;
        }
        catch (COMException)
        {
            return 7;
        }
        finally
        {
            if (taskbar != null && Marshal.IsComObject(taskbar))
            {
                Marshal.FinalReleaseComObject(taskbar);
            }
        }
    }

    [DllImport("user32.dll")]
    private static extern bool IsWindow(IntPtr window);

    [ComImport]
    [Guid("56FDF344-FD6D-11d0-958A-006097C9A090")]
    [ClassInterface(ClassInterfaceType.None)]
    private class TaskbarList
    {
    }

    [ComImport]
    [Guid("56FDF342-FD6D-11d0-958A-006097C9A090")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ITaskbarList
    {
        [PreserveSig]
        int HrInit();

        [PreserveSig]
        int AddTab(IntPtr window);

        [PreserveSig]
        int DeleteTab(IntPtr window);

        [PreserveSig]
        int ActivateTab(IntPtr window);

        [PreserveSig]
        int SetActiveAlt(IntPtr window);
    }
}
