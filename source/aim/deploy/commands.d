module aim.deploy.commands;

private
{
    import jaster.cli;
    import aim.common, aim.deploy, aim.secrets;
}

@Command("deploy init", "Initialises a deployment project.")
final class AimDeployInit : BaseCommand
{
    private IAimCliConfig!AimDeployConfig _config;

    this(IAimCliConfig!AimDeployConfig config)
    {
        this._config = config;
    }

    override int onExecute()
    {
        super.onExecute();

        this.createConfigFromUserInput();
        return 0;
    }

    private void createConfigFromUserInput()
    {
        this._config.edit((scope ref conf) 
        {
            conf.name        = Shell.getInput!string("Name: ");
            conf.domain      = Shell.getInput!string("Domain: ");
            conf.port        = Shell.getInput!ushort("Port: ");
            conf.projectType = Shell.getInputFromList("Type", [AimDeployConfig.Type.Docker]);

            final switch(conf.projectType)
            {
                case AimDeployConfig.Type.ERROR_UNKNOWN: throw new Exception("Nice try");

                case AimDeployConfig.Type.Docker:
                    this.getDockerFromUserInput(conf.docker);
                    break;
            }
        });
    }

    private void getDockerFromUserInput(scope ref AimDeployDockerSource conf)
    {
        conf.repository      = this.getNonNullStringInput("Repository: ");
        conf.imageName       = this.getNonNullStringInput("Image name: ");
        conf.loginUrl        = this.getNonNullStringInput("Login url: ");
        conf.username        = this.getNonNullStringInput("Docker username: ");
        conf.passwordOrToken = this.getNonNullStringInput("Docker token: ");
    }

    private string getNonNullStringInput(string prompt)
    {
        import jaster.cli    : Shell;
        import std.algorithm : all;
        import std.ascii     : isWhite;

        string value;
        while(value is null || value.length == 0 || value.all!isWhite)
            value = Shell.getInput!string(prompt);

        return value;
    }
}

@Command("deploy trigger", "Triggers a deployment attempt.")
final class AimDeployTrigger : BaseCommand
{
    private IDeployHandlerFactory _factory;
    private IAimDeployAddonFactory _addonFactory;
    private IAimCliConfig!AimDeployConfig _deployConf;

    this(IDeployHandlerFactory factory, IAimCliConfig!AimDeployConfig deployConf, IAimDeployAddonFactory addonFactory)
    {
        this._factory      = factory;
        this._deployConf   = deployConf;
        this._addonFactory = addonFactory;
    }

    override int onExecute()
    {
        import std.algorithm : map;
        import std.array     : array;
        import std.stdio     : writeln;
        super.onExecute();

        this._deployConf.value.enforceHasBeenInit();

        auto addons = this._deployConf.value.addons.map!(a => this._addonFactory.getAddonForType(a)).array;
        foreach(addon; addons)
            addon.onPreDeploy();

        auto handler    = this._factory.getHandlerForType(this._deployConf.value.projectType);
        auto statusCode = handler.deploy();

        if(statusCode >= 0)
        {
            foreach(addon; addons)
                addon.onPostDeploy();
        }

        return statusCode;
    }
}

@Command("deploy use", "Use an addon with this deployment project.")
final class AimDeployUse : BaseCommand
{
    private IAimDeployAddonFactory        _addonFactory;
    private IAimCliConfig!AimDeployConfig _deployConf;

    @CommandPositionalArg(0, "Addon", "The name of the addon to use. <values: Nginx>")
    string addon;

    this(IAimDeployAddonFactory addonFactory, IAimCliConfig!AimDeployConfig deployConf)
    {
        this._addonFactory = addonFactory;
        this._deployConf   = deployConf;
    }

    override int onExecute()
    {
        import std.algorithm : canFind;
        import std.conv      : to;

        super.onExecute();

        AimDeployAddons addon;

        try addon = this.addon.to!AimDeployAddons();
        catch(Exception ex) throw new Exception("Value '"~this.addon~"' is not a valid addon.");

        this._deployConf.edit((scope ref conf)
        {
            if(!conf.addons.canFind(addon))
            {
                auto instance = this._addonFactory.getAddonForType(addon);
                instance.onAddedToProject();
                conf.addons ~= addon;
            }
        });

        return 0;
    }
}

@Command("deploy trigger on", "Adds a new trigger into the project.")
final class AimDeployTriggerOn : BaseCommand
{
    private IAimDeployTriggerFactory      _triggerFactory;
    private IAimCliConfig!AimDeployConfig _deployConf;

    @CommandPositionalArg(0, "Trigger", "The name of the trigger to add. <values: GithubDeployment>")
    string trigger;

    this(IAimDeployTriggerFactory factory, IAimCliConfig!AimDeployConfig deployConf)
    {
        this._triggerFactory = factory;
        this._deployConf     = deployConf;
    }

    override int onExecute()
    {
        import std.algorithm : canFind;
        import std.conv      : to;

        super.onExecute();

        AimDeployTriggers trigger;

        try trigger = this.trigger.to!AimDeployTriggers();
        catch(Exception ex) throw new Exception("Value '"~this.trigger~"' is not a valid trigger.");

        this._deployConf.edit((scope ref conf)
        {
            if(!conf.triggers.canFind(trigger))
            {
                auto instance = this._triggerFactory.getTriggerForType(trigger);
                instance.onAddedToProject();
                conf.triggers ~= trigger;
            }
        });

        return 0;
    }
}

@Command("deploy trigger check", "Checks all triggers to see if a deployment should occur.")
final class AimDeployTriggerCheck : BaseCommand
{
    private IAimDeployTriggerFactory      _triggerFactory;
    private IAimCliConfig!AimDeployConfig _deployConf;
    private ICommandLineInterface         _cli;

    this(IAimDeployTriggerFactory factory, IAimCliConfig!AimDeployConfig deployConf, ICommandLineInterface cli)
    {
        this._triggerFactory = factory;
        this._deployConf     = deployConf;
        this._cli            = cli;
    }

    override int onExecute()
    {
        import std.algorithm : map, filter;
        import std.array     : array;

        super.onExecute();

        auto successfulTriggers = this._deployConf
                                      .value
                                      .triggers
                                      .map!((t)
                                      {
                                          Shell.verboseLogfln("Checking trigger %s", t);
                                          return this._triggerFactory.getTriggerForType(t);
                                      })
                                      .filter!((t) 
                                      {
                                          auto shouldTrigger = t.shouldTriggerDeploy();
                                          Shell.verboseLogfln(shouldTrigger ? "Trigger successful" : "Trigger failed");
                                          return shouldTrigger;
                                      })
                                      .array;

        int status;               
        if(successfulTriggers.length > 0)
            status = this._cli.parseAndExecute(["deploy", "trigger"], IgnoreFirstArg.no);
        else
            Shell.verboseLogfln("No triggers were successful");

        foreach(trigger; successfulTriggers)
            trigger.onPostDeploy(status == 0);

        return status;
    }
}