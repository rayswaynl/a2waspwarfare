# Miksuu Wiki Archive: Development Process

> Imported from [`Miksuu/a2waspwarfare.wiki`](https://github.com/Miksuu/a2waspwarfare/wiki) at commit `45ef3da` (`45ef3da367d65e6487de488bbe3b16a8a8b21ba3`) on `2026-06-03`. Original file: `Development-process-(for-Miksuu's-Portfolio-return).md`.
> This page preserves upstream community/developer documentation as historical provenance. It is not the current canonical source of truth for implementation details.

Current routing: [Community & Dev](Community-And-Dev) | [Miksuu upstream wiki import](Miksuu-Upstream-Wiki-Import)

Archive category: `developer-process-history`

---

## Archive Navigation

Previous: [Miksuu Wiki Archive: Discord Bot](Miksuu-Wiki-Archive-Discord-Bot) | Next: [Miksuu Wiki Archive: LoadoutManager](Miksuu-Wiki-Archive-LoadoutManager)

Related: [Community & Dev](Community-And-Dev) | [Developer history and upstream lessons](Developer-History-And-Upstream-Lessons) | [Testing/debugging/release workflow](Testing-Debugging-And-Release-Workflow)

The development process was complicated due to the different environment compared to the regular game programming due to the old architecture of the game. For example, there isn't a possibility to use breakpoints at all. We used ``WFBE_CO_FNC_LogContent`` function to get the values of certain variables to debug the mission. This with my lack of experience in SQF language, made the mission development a little bit complicated. To solve the common problems I referred to the [official documentation](https://community.bistudio.com/wiki/SQF_Syntax).

For the automation program, called [LoadoutManager](https://github.com/Miksuu/a2waspwarfare/tree/master/Tools/LoadoutManager), development was a lot easier since I was already quite familiar with the C# language. I re-used parts of the code from my previous projects to help build this program. A lot of the code was written using GPT-4, including the most complex algorithmic problem solving, such as when calculating all of the possible combinations for the aircraft loadouts, which speeded up the development overall. In the end we used this program for general automation too, so only one of the missions needs to be edited and the code is copied to every other map. More info on the the [LoadoutManager wiki page.](https://github.com/Miksuu/a2waspwarfare/wiki/LoadoutManager)

Generating patch notes was quite easy with our [Arma2Warfare GPT prompt](https://github.com/Miksuu/a2waspwarfare/blob/master/Tools/Arma2Warfare_GPT/CustomInstructions.md) (utilizing GPT-4). This prompt takes in Trello's cards and converts them to patch notes, provided that enough detail is in them. Sometimes OpenAI's Vision tool just failed, then just copy pasting the content to the chat bot solved the issue, however this is barely an issue anymore. In the future I might do more extensive project management systems that are integrated with Trello. This way more of the time for the project can be used on developing new features, instead of writing patch notes all day. Project management will be made easier this way too.

For each of the work in progress features, we created a single feature branch. Once these features were complete, they were merged to a test branch for testing. This way we could create multiple changes at once efficiently if they weren't dependent on each other. If an error was discovered during the testing, changes were made to the branch the feature was in, and it was merged to the test branch again with the fix implemented. Each of the features corresponded a single Trello card too with their own Todo lists.

During the development we ran into some performance issues. Most of them were related to loops that run on the server or client all the time, and sometimes modifying these made quite huge performance impact. Sometimes when bug was severe enough, it could even cause a server crash. However, thanks to our practices with the git that I described earlier, we were able to revert these features quite easily. Biggest impact that we had improving the performance was just allocating more cores for the server and the Headless Client, and instead of them running on two separate cores, we saw utilization of up to 5 cores effectively, which improved the performance by huge margin, alongside with our recent server upgrades.
