using Discord.WebSocket;
using Discord;
using System.Threading.Tasks;

public static class CommandHandler
{
    public static async Task InstallCommandsAsync()
    {
        try
        {
            Log.WriteLine("Registering /setup and /cleanup commands.", LogLevel.DEBUG);
            var client = BotReference.GetClientRef();

            // Register the /setup command (no options, uses current channel)
            var setupCommand = new SlashCommandBuilder()
                .WithName("setup")
                .WithDescription("Set this channel as the game status update channel (authorized users only)");

            // Register the /cleanup command to remove duplicate messages
            var cleanupCommand = new SlashCommandBuilder()
                .WithName("cleanup")
                .WithDescription("Remove duplicate status messages (authorized users only)");

            await client.Rest.CreateGuildCommand(setupCommand.Build(), Preferences.Instance.GuildID);
            await client.Rest.CreateGuildCommand(cleanupCommand.Build(), Preferences.Instance.GuildID);

            client.SlashCommandExecuted += SlashCommandHandler;
            Log.WriteLine("/setup and /cleanup commands registered.", LogLevel.DEBUG);
        }
        catch (Exception ex)
        {
            Log.WriteLine(ex.Message, LogLevel.ERROR);
            throw new InvalidOperationException(ex.Message);
        }
    }

    private static async Task SlashCommandHandler(SocketSlashCommand command)
    {
        try
        {
            Log.WriteLine($"Received slash command: {command.CommandName} from user {command.User.Id}", LogLevel.DEBUG);
            
            if (command.CommandName.ToLower() == "setup")
            {
                ulong userId = command.User.Id;
                
                Log.WriteLine($"Processing /setup command for user {userId}", LogLevel.DEBUG);
                
                if (!Preferences.Instance.IsUserAuthorized(userId))
                {
                    await command.RespondAsync("You are not authorized to use this command.", ephemeral: true);
                    Log.WriteLine($"Unauthorized user {userId} attempted to use /setup.", LogLevel.WARNING);
                    return;
                }

                Log.WriteLine("User is authorized, setting up game status channel...", LogLevel.DEBUG);

                // Set the current channel as the game status channel
                Preferences.Instance.GameStatusChannelID = command.Channel.Id;
                
                Log.WriteLine("Creating initial status message...", LogLevel.DEBUG);
                
                // Update channel name first
                var newChannelName = GameData.Instance.GetGameMapAndPlayerCountWithEmojiForChannelName();
                if (command.Channel is SocketGuildChannel guildChannel)
                {
                    await guildChannel.ModifyAsync(ch => ch.Name = newChannelName);
                    Log.WriteLine($"Channel name updated to: {newChannelName}", LogLevel.DEBUG);

                    // Update bot status
                    var client = BotReference.GetClientRef();
                    if (client != null)
                    {
                        await DiscordPresenceUpdater.TrySetGameAsync(client, newChannelName, "/setup command");
                    }
                }
                
                // Create the initial status message immediately
                var embed = CreateGameStatusEmbed();
                Discord.Rest.RestUserMessage? message = null;
                
                try
                {
                    message = await command.Channel.SendMessageAsync(embed: embed);
                    
                    Log.WriteLine($"Status message created with ID: {message.Id}", LogLevel.DEBUG);
                    
                    // Save the message ID for future updates
                    Preferences.Instance.GameStatusMessageID = message.Id;
                    Preferences.SaveToFile();
                }
                catch (Discord.Net.HttpException httpEx)
                {
                    Log.WriteLine($"Discord API Error: {httpEx.Message}", LogLevel.ERROR);
                    Log.WriteLine($"Error Code: {httpEx.HttpCode}", LogLevel.ERROR);
                    
                    string errorMessage = httpEx.HttpCode switch
                    {
                        System.Net.HttpStatusCode.Forbidden => "Bot doesn't have permission to send messages in this channel. Please check bot permissions.",
                        System.Net.HttpStatusCode.TooManyRequests => "Rate limited by Discord. Please wait a moment and try again.",
                        System.Net.HttpStatusCode.InternalServerError => "Discord server error. Please try again later.",
                        _ => $"Discord API error: {httpEx.Message}"
                    };
                    
                    await command.RespondAsync(errorMessage, ephemeral: true);
                    return;
                }
                catch (Exception ex)
                {
                    Log.WriteLine($"Unexpected error sending message: {ex.Message}", LogLevel.ERROR);
                    await command.RespondAsync("Failed to send status message. Please check bot permissions.", ephemeral: true);
                    return;
                }
                
                Log.WriteLine("Preferences saved, sending response...", LogLevel.DEBUG);
                
                await command.RespondAsync($"This channel (<#{command.Channel.Id}>) is now set for game status updates!", ephemeral: true);
                Log.WriteLine($"Game status channel set to {command.Channel.Id} with message ID {message?.Id} by user {userId}", LogLevel.DEBUG);
            }
            else if (command.CommandName.ToLower() == "cleanup")
            {
                ulong userId = command.User.Id;
                
                Log.WriteLine($"Processing /cleanup command for user {userId}", LogLevel.DEBUG);
                
                if (!Preferences.Instance.IsUserAuthorized(userId))
                {
                    await command.RespondAsync("You are not authorized to use this command.", ephemeral: true);
                    Log.WriteLine($"Unauthorized user {userId} attempted to use /cleanup.", LogLevel.WARNING);
                    return;
                }

                await command.DeferAsync(ephemeral: true);

                try
                {
                    var botId = BotReference.GetClientRef().CurrentUser.Id;
                    var messages = await command.Channel.GetMessagesAsync(50).FlattenAsync();
                    
                    var botStatusMessages = messages.Where(m => 
                        m.Author.Id == botId && 
                        m.Embeds.Any(e => 
                            e.Title?.Contains("Chernarus", StringComparison.OrdinalIgnoreCase) == true ||
                            e.Title?.Contains("Takistan", StringComparison.OrdinalIgnoreCase) == true ||
                            e.Description?.Contains("Score:", StringComparison.OrdinalIgnoreCase) == true
                        )
                    ).ToList();

                    if (botStatusMessages.Count <= 1)
                    {
                        await command.FollowupAsync("No duplicate messages found to clean up.", ephemeral: true);
                        return;
                    }

                    // Keep the newest message, delete the rest
                    var messagesToDelete = botStatusMessages.Skip(1);
                    int deletedCount = 0;

                    foreach (var oldMessage in messagesToDelete)
                    {
                        try
                        {
                            await oldMessage.DeleteAsync();
                            deletedCount++;
                            Log.WriteLine($"Deleted duplicate status message {oldMessage.Id}", LogLevel.DEBUG);
                        }
                        catch (Exception ex)
                        {
                            Log.WriteLine($"Failed to delete message {oldMessage.Id}: {ex.Message}", LogLevel.WARNING);
                        }
                    }

                    await command.FollowupAsync($"Cleaned up {deletedCount} duplicate status messages.", ephemeral: true);
                    Log.WriteLine($"Cleaned up {deletedCount} duplicate messages by user {userId}", LogLevel.DEBUG);
                }
                catch (Exception ex)
                {
                    Log.WriteLine($"Error during cleanup: {ex.Message}", LogLevel.ERROR);
                    await command.FollowupAsync("Failed to clean up messages. Check bot permissions.", ephemeral: true);
                }
            }
            else
            {
                await command.RespondAsync("Unknown command.", ephemeral: true);
                Log.WriteLine($"Unknown command received: {command.CommandName}", LogLevel.WARNING);
            }
        }
        catch (Exception ex)
        {
            Log.WriteLine($"Error in SlashCommandHandler: {ex.Message}", LogLevel.ERROR);
            Log.WriteLine($"Stack trace: {ex.StackTrace}", LogLevel.ERROR);
            
            try
            {
                if (!command.HasResponded)
                {
                    await command.RespondAsync("An error occurred while processing your command. Please check the logs.", ephemeral: true);
                }
            }
            catch (Exception responseEx)
            {
                Log.WriteLine($"Failed to send error response: {responseEx.Message}", LogLevel.ERROR);
            }
        }
    }

    private static Embed CreateGameStatusEmbed()
    {
        // Always load the latest game data from file
        GameData.Instance = GameData.LoadFromFile();

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
}
