module aim.daemon.daemon;

private
{
    import jaster.cli;
    import aim.common, aim.deploy, aim.secrets, aim.daemon;
}

final class AimDaemon
{
    private IAimCliConfig!AimDaemonConfig _daemonConfig;

    this(IAimCliConfig!AimDaemonConfig daemonConfig)
    {
        this._daemonConfig = daemonConfig;
    }

    void runForeverLoop()
    {
        import core.thread : Thread;
        import core.time   : seconds;

        Shell.useVerboseOutput = true;
        while(true)
        {
            tick();
            Thread.sleep(60.seconds);
            this._daemonConfig.reload();
        }
    }

    private void tick()
    {
        import std.file : exists, chdir;

        foreach(dir; this._daemonConfig.value.projectDirs)
        {
            if(!exists(dir))
                continue;

            chdir(dir);
            Shell.execute("aim deploy trigger check -v");
        }
    }
}