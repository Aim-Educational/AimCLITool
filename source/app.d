import jaster.cli.core, jaster.cli.util;
import std.algorithm : any;
import aim.secrets, aim.common, aim.deploy, aim.daemon;
import jaster.ioc;
import standardpaths;

int main(string[] args)
{
	auto provider = new ServiceProvider(
    [
        cliConfigure!AimSecretsConfig(AimSecretsConfig.CONF_FILE),
        cliConfigure!AimSecretsDefineValues(AimSecretsDefineValues.CONF_FILE),
        cliConfigure!AimDeployConfig(AimDeployConfig.CONF_FILE),
        cliConfigure!AimDaemonConfig(writablePath(StandardPath.config, "aimcli", FolderFlag.create)),
		ServiceInfo.asSingleton!(IFileDownloader, FileDownloader),
        ServiceInfo.asScoped!(IDeployHandlerFactory, DeployHandlerFactory),
        ServiceInfo.asScoped!(IAimDeployAddonFactory, AimDeployAddonFactory),
        ServiceInfo.asScoped!(IAimDeployTriggerFactory, AimDeployTriggerFactory),
        ServiceInfo.asSingleton!AimDaemon,
        addCommandLineInterfaceService()
    ]);

	auto core = new CommandLineInterface!(
		aim.secrets.commands,
		aim.deploy.commands,
        aim.deploy.docker_commands,
        aim.daemon.commands
	)(provider);

	return core.parseAndExecute(args);
}