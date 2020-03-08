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

            // TODO: Add a getInput variant that allows selecting a value from a given list.
            //       For now, we'll just assume that they want to always trigger from a github deployment.
            this.getGithubDeployFromUserInput(conf.triggerOnGithubDeployment);
        });
    }

    private void getDockerFromUserInput(scope ref AimDeployDockerSource conf)
    {
        conf.repository = this.getNonNullStringInput("Repository: ");
        conf.imageName  = this.getNonNullStringInput("Image name: ");
    }

    private void getGithubDeployFromUserInput(scope ref AimDeployGithubDeploymentTrigger conf)
    {
        conf.deployToken = this.getNonNullStringInput("Deploy Token: ");
        conf.repoOwner   = this.getNonNullStringInput("Repo Owner: ");
        conf.repoName    = this.getNonNullStringInput("Repo Name: ");
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

    @CommandNamedArg("f|force", "Forces a deployment, even if the current one is up to date.")
    Nullable!bool force;

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