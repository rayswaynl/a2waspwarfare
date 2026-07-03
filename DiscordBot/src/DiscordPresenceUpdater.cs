using Discord;
using Discord.WebSocket;

public static class DiscordPresenceUpdater
{
    private const int PresenceTimeoutMs = 30000;

    public static async Task<bool> TrySetGameAsync(DiscordSocketClient client, string statusText, string source)
    {
        Task presenceTask;

        try
        {
            presenceTask = client.SetGameAsync(statusText, null, ActivityType.Playing);
        }
        catch (Exception ex)
        {
            Log.WriteLine($"Bot presence update failed for {source}: {ex.Message}", LogLevel.WARNING);
            return false;
        }

        Task completedTask = await Task.WhenAny(presenceTask, Task.Delay(PresenceTimeoutMs));
        if (completedTask != presenceTask)
        {
            Log.WriteLine($"Bot presence update timed out after {PresenceTimeoutMs} ms for {source}. Continuing status updates.", LogLevel.WARNING);
            _ = ObserveLatePresenceFailure(presenceTask, source);
            return false;
        }

        try
        {
            await presenceTask;
            Log.WriteLine($"Bot status updated to: {statusText} ({source})", LogLevel.DEBUG);
            return true;
        }
        catch (Exception ex)
        {
            Log.WriteLine($"Bot presence update failed for {source}: {ex.Message}", LogLevel.WARNING);
            return false;
        }
    }

    private static async Task ObserveLatePresenceFailure(Task presenceTask, string source)
    {
        try
        {
            await presenceTask;
        }
        catch (Exception ex)
        {
            Log.WriteLine($"Late bot presence update failure after timeout for {source}: {ex.Message}", LogLevel.DEBUG);
        }
    }
}
