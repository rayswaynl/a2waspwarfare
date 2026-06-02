using Discord;
using Discord.WebSocket;
using System.Collections.Concurrent;

public class ProgramRuntime
{
    DiscordSocketClient client;

    public async Task ProgramRuntimeTask()
    {
        LogLevelNormalization.InitLogLevelNormalizationStrings();
        // Do not use the logging system before this !!!

        // Load the initial game data
        GameData.Instance = GameData.LoadFromFile();

        // Set up client and return it
        client = BotReference.SetClientRefAndReturnIt();

        // Check if token file exists
        if (!File.Exists("token.txt"))
        {
            Log.WriteLine("Token file 'token.txt' not found in the application directory. Please create this file with your Discord bot token.", LogLevel.ERROR);
            return;
        }

        // Reads token from the same directory as the .exe
        var token = File.ReadAllText("token.txt");
        
        // Check if token is empty or whitespace
        if (string.IsNullOrWhiteSpace(token))
        {
            Log.WriteLine("Token file 'token.txt' is empty. Please add your Discord bot token to this file.", LogLevel.ERROR);
            return;
        }
        
        await client.LoginAsync(TokenType.Bot, token);
        await client.StartAsync();

        client.Ready += async () =>
        {
            if (!BotReference.Instance.ConnectionState)
            {
                BotReference.Instance.ConnectionState = true;
                Log.WriteLine("Bot is connected!", LogLevel.DEBUG);

                await GameDataDeSerialization.DeSerializeGameDataFromExtension();

                await SetupProgramListenersAndSchedulers();

                //new GameDataUpdateEvent(eventManager.ClassScheduledEvents);
            }
            // else
            // {
            //     //HandleBotReconnection();
            // }
        };

        // Block this task until the program is closed.
        await Task.Delay(-1);
    }

    private async Task SetupProgramListenersAndSchedulers()
    {
        // Install commands - temporarily disabled until framework is properly referenced
        await CommandHandler.InstallCommandsAsync();

        // Start game status updater
        var gameStatusUpdater = new GameStatusUpdater();
        gameStatusUpdater.StartGameStatusUpdates(client);

        // Start in-game player-stats ingest (RPT tail -> stats.json). No-op unless Preferences.StatsEnabled.
        new StatsService().Start();

        Log.WriteLine("Program listeners and schedulers setup completed", LogLevel.DEBUG);
    }

    // private async Task SetupEventScheduler()
    // {
    //     await Database.GetInstance<DiscordBotDatabase>().EventScheduler.CheckCurrentTimeAndExecuteScheduledEvents(true);

    //     Thread secondThread = new Thread(Database.GetInstance<DiscordBotDatabase>().EventScheduler.EventSchedulerLoop);
    //     secondThread.Start();
    // }

    // private void HandleBotReconnection() 
    // { 
    //     Log.WriteLine("Bot was already connected!", LogLevel.WARNING);

    //     client.ButtonExecuted -= ButtonHandler.HandleButtonPress;

    //     SetupListeners();
    // }

    // private void SetupListeners()
    // {
    //     client.ButtonExecuted += ButtonHandler.HandleButtonPress;
    // }
}