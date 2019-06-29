import jaster.cli.core, jaster.cli.util;
import std.algorithm : any;
import aim.secrets, aim.deploy.commands;

int main(string[] args)
{
	auto core = new CommandLineInterface!(
		aim.secrets.commands,
		aim.deploy.commands
	);

	return core.parseAndExecute(args);
}
