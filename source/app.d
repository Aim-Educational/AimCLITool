import jaster.cli.core, jaster.cli.util;
import std.algorithm : any;
import aim.secrets, aim.common, aim.deploy;
import jaster.ioc.container;

int main(string[] args)
{
	auto provider = new ServiceProvider();
	provider.configureServices((scope services)
	{
		services.cliConfigure!AimSecretsConfig(AimSecretsConfig.CONF_FILE);
		services.cliConfigure!AimSecretsDefineValues(AimSecretsDefineValues.CONF_FILE);
		services.addSingleton!(IAimDeployPacker, AimDeployPacker);
	});

	auto core = new CommandLineInterface!(
		aim.secrets.commands,
		aim.deploy.commands
	)(provider);

	return core.parseAndExecute(args);
}