import jaster.cli.core, jaster.cli.util;
import std.algorithm : any;
import aim.secrets, aim.deploy.commands;

int main(string[] args)
{
	Shell.useVerboseOutput = true; // Until we have proper support for it.

	auto core = new CommandLineInterface!(
		aim.secrets.commands,
		aim.deploy.commands
	);

	return core.parseAndExecute(args);
}
