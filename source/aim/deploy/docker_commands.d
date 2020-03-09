module aim.deploy.docker_commands;

private
{
    import jaster.cli;
    import aim.common, aim.deploy, aim.secrets;
}

abstract class DockerDeployBaseCommand : BaseCommand
{
    protected IAimCliConfig!AimDeployConfig deployConfig;

    this(IAimCliConfig!AimDeployConfig config)
    {
        this.deployConfig = config;
    }

    override int onExecute()
    {
        import std.exception : enforce;

        enforce(this.deployConfig.value.projectType == AimDeployConfig.Type.Docker, "This is not a Docker project.");
        return super.onExecute();
    }
}

@Command("deploy docker memory", "Sets the amount of memory the container can use.")
final class AimDeployDockerMemoryCommand : DockerDeployBaseCommand
{
    @CommandPositionalArg(0, "limit", "A 'docker -m' compatible memory limit string. Use `0b` to remove the limit.")
    string limit;

    this(IAimCliConfig!AimDeployConfig config)
    {
        super(config);
    }

    override int onExecute()
    {
        import std.regex     : matchFirst;
        import std.exception : enforce;

        super.onExecute();
        enforce(!matchFirst(this.limit, `^\d+[bkmg]$`).empty, "'"~this.limit~"' is not a valid memory string.");

        if(this.limit == "0b")
            this.limit = null;

        super.deployConfig.value.docker.memoryLimit = this.limit;
        return 0;
    }
}