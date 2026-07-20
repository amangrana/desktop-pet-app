using System;
using System.Collections.Generic;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;

internal static class CredentialHelper
{
    private const string Protocol = "DPC1";
    private const string AllowedTargetPrefix = "DesktopPet.";
    private const uint CredentialTypeGeneric = 1;
    private const uint CredentialPersistLocalMachine = 2;
    private const int ErrorNotFound = 1168;

    private static int Main(string[] args)
    {
        Dictionary<string, string> options = ParseArguments(args);
        int port;
        string session;
        string target;
        string operation;
        if (!TryGetInteger(options, "--port", out port)
            || port < 1
            || port > 65535
            || !options.TryGetValue("--session", out session)
            || String.IsNullOrWhiteSpace(session)
            || session.IndexOf('|') >= 0
            || !options.TryGetValue("--target", out target)
            || !target.StartsWith(
                AllowedTargetPrefix,
                StringComparison.Ordinal
            )
            || !options.TryGetValue("--operation", out operation)
            || (operation != "read"
                && operation != "write"
                && operation != "delete"))
        {
            return 2;
        }

        try
        {
            using (TcpClient client = new TcpClient())
            {
                client.SendTimeout = 3000;
                client.ReceiveTimeout = 3000;
                client.Connect("127.0.0.1", port);
                using (NetworkStream stream = client.GetStream())
                using (System.IO.StreamReader reader =
                    new System.IO.StreamReader(
                        stream,
                        new UTF8Encoding(false),
                        false,
                        1024,
                        true
                    ))
                using (System.IO.StreamWriter writer =
                    new System.IO.StreamWriter(
                        stream,
                        new UTF8Encoding(false),
                        1024,
                        true
                    ))
                {
                    writer.AutoFlush = true;
                    if (operation == "read")
                    {
                        return ReadCredential(target, session, writer);
                    }
                    if (operation == "delete")
                    {
                        return DeleteCredential(target, session, writer);
                    }
                    return WriteCredential(
                        target,
                        session,
                        reader,
                        writer
                    );
                }
            }
        }
        catch
        {
            return 3;
        }
    }

    private static int ReadCredential(
        string target,
        string session,
        System.IO.StreamWriter writer
    )
    {
        IntPtr credentialPointer;
        if (!CredReadW(
            target,
            CredentialTypeGeneric,
            0,
            out credentialPointer
        ))
        {
            int error = Marshal.GetLastWin32Error();
            if (error == ErrorNotFound)
            {
                Send(writer, session, "EMPTY", "");
                return 0;
            }
            Send(writer, session, "ERROR", "read_failed_" + error);
            return 4;
        }

        try
        {
            Credential credential = (Credential)Marshal.PtrToStructure(
                credentialPointer,
                typeof(Credential)
            );
            byte[] secret = new byte[credential.CredentialBlobSize];
            if (secret.Length > 0)
            {
                Marshal.Copy(
                    credential.CredentialBlob,
                    secret,
                    0,
                    secret.Length
                );
            }
            try
            {
                Send(
                    writer,
                    session,
                    "VALUE",
                    Convert.ToBase64String(secret)
                );
            }
            finally
            {
                Array.Clear(secret, 0, secret.Length);
            }
            return 0;
        }
        finally
        {
            CredFree(credentialPointer);
        }
    }

    private static int WriteCredential(
        string target,
        string session,
        System.IO.StreamReader reader,
        System.IO.StreamWriter writer
    )
    {
        Send(writer, session, "READY", "");
        string line = reader.ReadLine();
        string[] parts = (
            line == null
            ? new string[0]
            : line.Split(new char[] {'|'}, 4)
        );
        if (parts.Length != 4
            || parts[0] != Protocol
            || parts[1] != session
            || parts[2] != "SECRET")
        {
            Send(writer, session, "ERROR", "invalid_protocol");
            return 5;
        }

        byte[] secret;
        try
        {
            secret = Convert.FromBase64String(parts[3]);
        }
        catch (FormatException)
        {
            Send(writer, session, "ERROR", "invalid_secret");
            return 6;
        }
        if (secret.Length == 0 || secret.Length > 2560)
        {
            Array.Clear(secret, 0, secret.Length);
            Send(writer, session, "ERROR", "invalid_secret_size");
            return 7;
        }

        IntPtr secretPointer = Marshal.AllocHGlobal(secret.Length);
        try
        {
            Marshal.Copy(secret, 0, secretPointer, secret.Length);
            Credential credential = new Credential();
            credential.Type = CredentialTypeGeneric;
            credential.TargetName = target;
            credential.CredentialBlobSize = (uint)secret.Length;
            credential.CredentialBlob = secretPointer;
            credential.Persist = CredentialPersistLocalMachine;
            credential.UserName = "Google Calendar OAuth";
            if (!CredWriteW(ref credential, 0))
            {
                int error = Marshal.GetLastWin32Error();
                Send(writer, session, "ERROR", "write_failed_" + error);
                return 8;
            }
            Send(writer, session, "OK", "");
            return 0;
        }
        finally
        {
            for (int index = 0; index < secret.Length; index++)
            {
                Marshal.WriteByte(secretPointer, index, 0);
            }
            Marshal.FreeHGlobal(secretPointer);
            Array.Clear(secret, 0, secret.Length);
        }
    }

    private static int DeleteCredential(
        string target,
        string session,
        System.IO.StreamWriter writer
    )
    {
        if (!CredDeleteW(target, CredentialTypeGeneric, 0))
        {
            int error = Marshal.GetLastWin32Error();
            if (error != ErrorNotFound)
            {
                Send(
                    writer,
                    session,
                    "ERROR",
                    "delete_failed_" + error
                );
                return 9;
            }
        }
        Send(writer, session, "OK", "");
        return 0;
    }

    private static void Send(
        System.IO.StreamWriter writer,
        string session,
        string kind,
        string value
    )
    {
        writer.WriteLine(
            Protocol + "|" + session + "|" + kind + "|" + value
        );
    }

    private static Dictionary<string, string> ParseArguments(string[] args)
    {
        Dictionary<string, string> options =
            new Dictionary<string, string>(StringComparer.Ordinal);
        for (int index = 0; index + 1 < args.Length; index++)
        {
            string argument = args[index];
            if (argument.StartsWith("--", StringComparison.Ordinal))
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

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct Credential
    {
        public uint Flags;
        public uint Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint Persist;
        public uint AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    [DllImport(
        "advapi32.dll",
        EntryPoint = "CredReadW",
        CharSet = CharSet.Unicode,
        SetLastError = true
    )]
    private static extern bool CredReadW(
        string target,
        uint type,
        uint flags,
        out IntPtr credential
    );

    [DllImport(
        "advapi32.dll",
        EntryPoint = "CredWriteW",
        CharSet = CharSet.Unicode,
        SetLastError = true
    )]
    private static extern bool CredWriteW(
        ref Credential credential,
        uint flags
    );

    [DllImport(
        "advapi32.dll",
        EntryPoint = "CredDeleteW",
        CharSet = CharSet.Unicode,
        SetLastError = true
    )]
    private static extern bool CredDeleteW(
        string target,
        uint type,
        uint flags
    );

    [DllImport("advapi32.dll")]
    private static extern void CredFree(IntPtr buffer);
}
