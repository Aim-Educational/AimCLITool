module aim.daemon.commands;

private
{
    import jaster.cli;
    import aim.common, aim.deploy, aim.secrets, aim.daemon;
}

@Command("daemon run", "Runs the program in daemon mode.")
final class AimDaemonRun : BaseCommand
{
    private AimDaemon _daemon;

    this(AimDaemon daemon)
    {
        this._daemon = daemon;
    }

    override int onExecute()
    {
        this._daemon.runForeverLoop();
        return 0;
    }
}

@Command("daemon watch", "Register the current directory as a deployment project to the daemon.")
final class AimDaemonWatch : BaseCommand
{
    private IAimCliConfig!AimDaemonConfig _config;

    this(IAimCliConfig!AimDaemonConfig config)
    {
        this._config = config;
    }

    override int onExecute()
    {
        import std.algorithm : canFind;
        import std.file      : getcwd;

        this._config.edit((scope ref conf)
        {
            const dir = getcwd();

            if(!conf.projectDirs.canFind(dir))
                conf.projectDirs ~= dir;
        });   
        return 0;
    }
}

@Command("daemon register systemd", "Creates a systemd service that runs AimCLITool in Daemon mode.")
final class AimDaemonRegisterSystemd : BaseCommand
{
    private static immutable SYSTEMD_TEMPLATE = import("deploy/systemd.service");
    private static immutable SERVICE_PATH     = "/lib/systemd/system/aimd.service";

    override int onExecute()
    {
        import std.file             : thisExePath, write;
        import aim.common.templater : Templater;

        write(SERVICE_PATH, Templater.resolveTemplate(["$AIM_PATH": thisExePath], SYSTEMD_TEMPLATE));
        Shell.executeEnforceStatusZero("systemctl start aimd");

        return 0;
    }
}