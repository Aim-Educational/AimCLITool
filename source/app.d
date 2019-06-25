import jaster.cli.core;
import aim.secrets;

int main(string[] args)
{
	auto core = new CommandLineInterface!(
		aim.secrets.commands
	);

	return core.parseAndExecute(args);
}
