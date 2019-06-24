import jaster.cli.core;
import tool.commands;

int main(string[] args)
{
	if(args.length == 1)
		args.length = 0;
	else
		args = args[1..$];

	auto core = new CommandLineInterface!(
		tool.commands
	);

	return core.parseAndExecute(args);
}
