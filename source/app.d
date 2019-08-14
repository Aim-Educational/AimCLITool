import jaster.cli.core, jaster.cli.util;
import std.algorithm : any;
import aim.secrets, aim.common;
import jaster.ioc.container;

int main(string[] args)
{
	auto provider = new ServiceProvider();
	provider.configureServices((scope services)
	{
		services.cliConfigure!AimSecretsConfig(AimSecretsConfig.CONF_FILE);
		services.cliConfigure!AimSecretsDefineValues(AimSecretsDefineValues.CONF_FILE);
	});

	auto core = new CommandLineInterface!(
		aim.secrets.commands
	)(provider);

	return core.parseAndExecute(args);
}