using System;
using System.Threading;
using ManagedBass;

public class RADIO : BaseExtensionClass
{
    // Args:
    // [0] Sub-command: PLAY | STOP | VOLUME
    // [1] PLAY: stream URL. VOLUME: 0-100 integer. (STOP takes no further args.)
    //
    // PLAY/STOP/VOLUME must all return to Arma instantly (callExtension cannot block on a
    // network connect), so the actual BASS connect happens on a background thread; the extension
    // call itself only ever touches in-memory state and returns immediately. Mirrors the
    // fire-and-forget shape already used by the AntiStack request/poll pattern, minus the poll
    // (BASS plays the stream autonomously once BASS_StreamCreateURL succeeds).

    private static int currentStreamHandle;
    private static readonly object streamLock = new object();
    private static bool bassInitialized;

    public override void ActivateExtensionMethodOnTheDerivedClass(string[] _args)
    {
        try
        {
            if (_args.Length == 0)
            {
                Log.WriteLine("RADIO called with no sub-command.", LogLevel.CRITICAL);
                return;
            }

            if (!EnsureBassInitialized())
            {
                // Fail closed: no sound device / already-initialized-elsewhere, no BASS calls past this point.
                return;
            }

            string subCommand = _args[0].Trim().ToUpperInvariant();
            switch (subCommand)
            {
                case "PLAY":
                    if (_args.Length < 2 || string.IsNullOrWhiteSpace(_args[1]))
                    {
                        Log.WriteLine("RADIO,PLAY requires a stream URL.", LogLevel.CRITICAL);
                        return;
                    }

                    string url = _args[1];
                    ThreadPool.QueueUserWorkItem(_ => PlayStream(url));
                    break;

                case "STOP":
                    StopStream();
                    break;

                case "VOLUME":
                    int volumePercent;
                    if (_args.Length < 2 || !int.TryParse(_args[1], out volumePercent))
                    {
                        Log.WriteLine("RADIO,VOLUME requires a 0-100 integer.", LogLevel.CRITICAL);
                        return;
                    }
                    SetVolume(volumePercent);
                    break;

                default:
                    Log.WriteLine("Unknown RADIO sub-command: " + subCommand, LogLevel.CRITICAL);
                    break;
            }
        }
        catch (Exception _ex)
        {
            // Third-party stream (music.miksuu.com) or the local audio device can fail in ways
            // we don't control - never let that propagate into an RPT-spamming exception loop.
            Log.WriteLine("RADIO exception: " + _ex.Message, LogLevel.CRITICAL);
        }
    }

    // Radio state is purely in-memory/per-client - nothing here belongs in GameData, and the base
    // implementation's SerializeDB() would otherwise create C:\a2waspwarfare\Data\database.json on
    // every player's own PC on every PLAY/STOP/VOLUME call for no reason. Skip it for this extension.
    public override void ActivateExtensionMethodAndSerialize(string[] _args)
    {
        ActivateExtensionMethodOnTheDerivedClass(_args);
    }

    private static bool EnsureBassInitialized()
    {
        lock (streamLock)
        {
            if (bassInitialized)
            {
                return true;
            }

            if (!Bass.Init())
            {
                Log.WriteLine("BASS_Init failed: " + Bass.LastError, LogLevel.CRITICAL);
                return false;
            }

            bassInitialized = true;
            return true;
        }
    }

    private static void PlayStream(string _url)
    {
        try
        {
            lock (streamLock)
            {
                FreeCurrentStreamNoLock();

                int handle = Bass.CreateStream(_url, 0, BassFlags.StreamStatus | BassFlags.AutoFree, null, IntPtr.Zero);
                if (handle == 0)
                {
                    Log.WriteLine("RADIO,PLAY failed to open " + _url + ": " + Bass.LastError, LogLevel.CRITICAL);
                    return;
                }

                if (!Bass.ChannelPlay(handle, false))
                {
                    Log.WriteLine("RADIO,PLAY failed to start playback: " + Bass.LastError, LogLevel.CRITICAL);
                    Bass.StreamFree(handle);
                    return;
                }

                currentStreamHandle = handle;
            }
        }
        catch (Exception _ex)
        {
            Log.WriteLine("RADIO,PLAY exception for " + _url + ": " + _ex.Message, LogLevel.CRITICAL);
        }
    }

    private static void StopStream()
    {
        lock (streamLock)
        {
            FreeCurrentStreamNoLock();
        }
    }

    private static void SetVolume(int _volumePercent)
    {
        int clamped = Math.Max(0, Math.Min(100, _volumePercent));

        lock (streamLock)
        {
            if (currentStreamHandle == 0)
            {
                return;
            }

            Bass.ChannelSetAttribute(currentStreamHandle, ChannelAttribute.Volume, clamped / 100f);
        }
    }

    // Caller must already hold streamLock.
    private static void FreeCurrentStreamNoLock()
    {
        if (currentStreamHandle != 0)
        {
            Bass.StreamFree(currentStreamHandle);
            currentStreamHandle = 0;
        }
    }
}
