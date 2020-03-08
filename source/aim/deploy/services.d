module aim.deploy.services;

import jaster.ioc, jaster.cli;
import aim.deploy.data, aim.common, aim.secrets.data;

interface IDeployHandlerFactory
{
    IDeployHandler getHandlerForType(AimDeployConfig.Type type);
}

interface IDeployHandler
{
    int deploy();
}

final class DeployHandlerFactory : IDeployHandlerFactory
{
    private ServiceScopeAccessor _scope;

    this(ServiceScopeAccessor scope_)
    {
        this._scope = scope_;
    }

    override IDeployHandler getHandlerForType(AimDeployConfig.Type type)
    {
        Shell.verboseLogfln("Creating handler for project type '%s'", type);

        auto serviceScope = this._scope.serviceScope;
        final switch(type) with(AimDeployConfig.Type)
        {
            case ERROR_UNKNOWN: throw new Exception("Nice try");
            case Docker:
                return Injector.construct!DockerDeployHandler(serviceScope);
        }
    }
}

final class DockerDeployHandler : IDeployHandler
{
    private IAimCliConfig!AimDeployConfig        _deployConf;
    private IAimCliConfig!AimSecretsConfig       _secretsConf;
    private IAimCliConfig!AimSecretsDefineValues _valuesConf;
    private ICommandLineInterface                _cli;

    this(
        IAimCliConfig!AimDeployConfig deployConf,
        IAimCliConfig!AimSecretsConfig secretsConf,
        ICommandLineInterface cli,
        IAimCliConfig!AimSecretsDefineValues valuesConf
    )
    {
        this._secretsConf = secretsConf;
        this._valuesConf  = valuesConf;
        this._deployConf  = deployConf;
        this._cli         = cli;
    }

    override int deploy()
    {
        import std.conv : to;

        this._cli.parseAndExecute(["secrets", "verify", "-v"], IgnoreFirstArg.no);

        Shell.enforceCommandExists("docker");
        Shell.executeEnforceStatusZero("docker pull " ~ this.getDockerPullString());
        Shell.execute("docker stop "~this.getContainerName());
        Shell.executeEnforceStatusZero(
            "docker run"
           ~" --name="~this.getContainerName
           ~" --restart=always"
           ~" -p 127.0.0.1:"~this._deployConf.value.port.to!string~":80"
           ~this.getEnvironmentLines()
           ~" -d "
           ~this.getDockerPullString()
        );

        return 0;
    }

    private string getDockerPullString()
    {
        string str = this._deployConf.value.docker.repository;

        if(str[$-1] != '/')
            str ~= '/';

        str ~= this._deployConf.value.docker.imageName;

        if(this._deployConf.value.docker.tagInUse.length > 0)
        {
            str ~= ':';
            str ~= this._deployConf.value.docker.tagInUse;
        }

        return str;
    }

    private string getContainerName()
    {
        import std.uni : toLower;

        return "aim-cli-"~this._deployConf.value.docker.imageName.toLower();
    }

    private string getEnvironmentLines()
    {
        import std.exception : assumeUnique;
        import std.process   : environment;

        char[] output;

        foreach(secret; this._secretsConf.value.definitions)
        {
            environment[secret.name] = this._valuesConf.value.getValueByName(secret.name);
            output ~= " -e "~secret.name;
        }

        return output.assumeUnique;
    }
}