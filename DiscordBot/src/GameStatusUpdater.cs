using Discord;
using Discord.WebSocket;
using System.Timers;

public class GameStatusUpdater
{
    private System.Timers.Timer? updateTimer;
    private DiscordSocketClient? client;
    private const int UPDATE_INTERVAL_SECONDS = 60; // Update every 60 seconds - change this for different intervals
    private readonly SemaphoreSlim updateSemaphore = new SemaphoreSlim(1, 1); // Prevent multiple updates at once
    private const int DISCORD_TIMEOUT_MS = 30000; // 30 second timeout for Discord operations
    private int consecutiveTimeouts = 0;

    public void StartGameStatusUpdates(DiscordSocketClient _client)
    {
        client = _client;
        
        // Create timer that fires with high precision
        updateTimer = new System.Timers.Timer(UPDATE_INTERVAL_SECONDS * 1000); // Convert seconds to milliseconds
        updateTimer.Elapsed += OnUpdateTimerElapsed;
        updateTimer.AutoReset = true;
        updateTimer.Enabled = true; // More reliable than Start()

        Log.WriteLine($"Game status updater started - will update every {UPDATE_INTERVAL_SECONDS} seconds", LogLevel.DEBUG);
    }

    private async void OnUpdateTimerElapsed(object? sender, ElapsedEventArgs e)
    {
        // Prevent multiple updates from running simultaneously
        if (!await updateSemaphore.WaitAsync(100)) // Don't wait long, just skip if busy
        {
            Log.WriteLine("Skipping update - previous update still in progress", LogLevel.DEBUG);
            return;
        }

        try
        {
            Log.WriteLine($"Timer elapsed - starting update at {DateTime.Now:HH:mm:ss}", LogLevel.DEBUG);
            await UpdateGameStatus();
            Log.WriteLine($"Update completed at {DateTime.Now:HH:mm:ss}", LogLevel.DEBUG);
        }
        catch (Exception ex)
        {
            Log.WriteLine($"Error in game status update: {ex.Message}", LogLevel.ERROR);
        }
        finally
        {
            updateSemaphore.Release();
        }
    }

    private async Task UpdateGameStatus()
    {
        if (client == null)
        {
            Log.WriteLine("Client is null, cannot update game status", LogLevel.ERROR);
            return;
        }

        var gameStatusChannelId = Preferences.Instance.GameStatusChannelID;
        var gameStatusMessageId = Preferences.Instance.GameStatusMessageID;
        
        if (gameStatusChannelId == null)
        {
            Log.WriteLine("No game status channel configured, skipping update", LogLevel.DEBUG);
            return;
        }

        var guild = client.GetGuild(Preferences.Instance.GuildID);
        if (guild == null)
        {
            Log.WriteLine("Guild not found, cannot update game status", LogLevel.ERROR);
            return;
        }

        var channel = guild.GetChannel(gameStatusChannelId.Value) as IMessageChannel;
        if (channel == null)
        {
            Log.WriteLine($"Game status channel {gameStatusChannelId} not found", LogLevel.ERROR);
            return;
        }

        // Always load the latest game data from file
        GameData.Instance = GameData.LoadFromFile();

        // Create the updated game status embed
        var embed = CreateGameStatusEmbed();
        
        try
        {
            // Update channel name first (with timeout)
            var newChannelName = GameData.Instance.GetGameMapAndPlayerCountWithEmojiForChannelName();
            using (var cts = new CancellationTokenSource(DISCORD_TIMEOUT_MS))
            {
                await guild.GetChannel(gameStatusChannelId.Value).ModifyAsync(ch => ch.Name = newChannelName, new RequestOptions { CancelToken = cts.Token });
                Log.WriteLine($"Channel name updated to: {newChannelName}", LogLevel.DEBUG);
            }

            // Update bot status (with timeout)
            if (client != null)
            {
                await DiscordPresenceUpdater.TrySetGameAsync(client, newChannelName, "status timer");
            }
            
            // Try to get and modify the existing message, or create a new one if it doesn't exist
            if (gameStatusMessageId.HasValue)
            {
                try
                {
                    using (var cts = new CancellationTokenSource(DISCORD_TIMEOUT_MS))
                    {
                        var existingMessage = await channel.GetMessageAsync(gameStatusMessageId.Value, CacheMode.AllowDownload, new RequestOptions { CancelToken = cts.Token });
                        if (existingMessage is IUserMessage userMessage)
                        {
                            await userMessage.ModifyAsync(msg => msg.Embed = embed, new RequestOptions { CancelToken = cts.Token });
                            Log.WriteLine($"Game status message {gameStatusMessageId} updated in channel {gameStatusChannelId}", LogLevel.DEBUG);
                            consecutiveTimeouts = 0; // Reset timeout counter on success
                        }
                        else
                        {
                            Log.WriteLine($"Could not find message {gameStatusMessageId}, it may have been deleted. Creating new message.", LogLevel.WARNING);
                            await CreateNewStatusMessage(channel, embed, gameStatusChannelId.Value);
                        }
                    }
                }
                catch (TaskCanceledException)
                {
                    consecutiveTimeouts++;
                    Log.WriteLine($"Timeout updating message (#{consecutiveTimeouts}). Will retry next update.", LogLevel.WARNING);
                    
                    // Log the timeout but don't reset message ID - just continue trying with the same message ID
                    Log.WriteLine($"Consecutive timeouts count: {consecutiveTimeouts}", LogLevel.DEBUG);
                    return; // Don't create new message on timeout
                }
            }
            else
            {
                Log.WriteLine("No game status message ID configured, creating new message", LogLevel.DEBUG);
                await CreateNewStatusMessage(channel, embed, gameStatusChannelId.Value);
            }
        }
        catch (TaskCanceledException)
        {
            consecutiveTimeouts++;
            Log.WriteLine($"Timeout during update operation (#{consecutiveTimeouts}). Will retry next update.", LogLevel.WARNING);
            Log.WriteLine($"Consecutive timeouts count: {consecutiveTimeouts}", LogLevel.DEBUG);
        }
        catch (Exception ex)
        {
            Log.WriteLine($"Failed to update game status message: {ex.Message}", LogLevel.ERROR);
            // Log the error but don't reset message ID - just continue trying with the same message ID
            consecutiveTimeouts++;
            Log.WriteLine($"Consecutive errors count: {consecutiveTimeouts}", LogLevel.DEBUG);
        }
    }

    private async Task CreateNewStatusMessage(IMessageChannel channel, Embed embed, ulong channelId)
    {
        try
        {
            using (var cts = new CancellationTokenSource(DISCORD_TIMEOUT_MS))
            {
                var newMessage = await channel.SendMessageAsync(embed: embed, options: new RequestOptions { CancelToken = cts.Token });
                
                Log.WriteLine($"New status message created with ID: {newMessage.Id}", LogLevel.DEBUG);
                
                // Save the new message ID for future updates
                Preferences.Instance.GameStatusMessageID = newMessage.Id;
                Preferences.SaveToFile();
                
                Log.WriteLine($"New game status message {newMessage.Id} created in channel {channelId}", LogLevel.DEBUG);
                consecutiveTimeouts = 0; // Reset timeout counter on success
            }
        }
        catch (TaskCanceledException)
        {
            consecutiveTimeouts++;
            Log.WriteLine($"Timeout creating new status message (#{consecutiveTimeouts}). Will retry next update.", LogLevel.WARNING);
            Log.WriteLine($"Consecutive timeouts count: {consecutiveTimeouts}", LogLevel.DEBUG);
        }
        catch (Exception ex)
        {
            Log.WriteLine($"Failed to create new status message: {ex.Message}", LogLevel.ERROR);
            consecutiveTimeouts++;
            Log.WriteLine($"Consecutive errors count: {consecutiveTimeouts}", LogLevel.DEBUG);
        }
    }



    private Embed CreateGameStatusEmbed()
    {
        var gsm = new GameStatusMessage();
        gsm.GenerateMessage();

        var embedBuilder = new EmbedBuilder()
            .WithTitle(gsm.MessageEmbedTitle)
            .WithDescription(gsm.MessageDescription)
            .WithColor(gsm.MessageEmbedColor)
            .WithFooter(gsm.GenerateMessageFooter())
            .WithTimestamp(DateTimeOffset.UtcNow);

        return embedBuilder.Build();
    }

    public void StopGameStatusUpdates()
    {
        if (updateTimer != null)
        {
            updateTimer.Stop();
            updateTimer.Dispose();
            updateTimer = null;
        }

        updateSemaphore.Dispose();
        Log.WriteLine("Game status updater stopped", LogLevel.DEBUG);
    }
}
