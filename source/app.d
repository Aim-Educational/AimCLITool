import jaster.cli.core, jaster.cli.util;
import std.algorithm : any;
import aim.secrets, aim.common, aim.deploy;
import jaster.ioc;

int main(string[] args)
{
	auto provider = new ServiceProvider(
    [
        cliConfigure!AimSecretsConfig(AimSecretsConfig.CONF_FILE),
        cliConfigure!AimSecretsDefineValues(AimSecretsDefineValues.CONF_FILE),
        cliConfigure!AimDeployConfig(AimDeployConfig.CONF_FILE),
		ServiceInfo.asSingleton!(IFileDownloader, FileDownloader),
        ServiceInfo.asScoped!(IDeployHandlerFactory, DeployHandlerFactory),
        ServiceInfo.asScoped!(IAimDeployAddonFactory, AimDeployAddonFactory),
        ServiceInfo.asScoped!(IAimDeployTriggerFactory, AimDeployTriggerFactory),
        addCommandLineInterfaceService()
    ]);

	auto core = new CommandLineInterface!(
		aim.secrets.commands,
		aim.deploy.commands,
        aim.deploy.docker_commands
	)(provider);

	return core.parseAndExecute(args);
}