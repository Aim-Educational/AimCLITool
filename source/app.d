import jaster.cli.core;
import aim.secrets;

int main(string[] args)
{
	if(args.length == 1)
		args.length = 0;
	else
		args = args[1..$];

	auto core = new CommandLineInterface!(
		aim.secrets.commands
	);

	return core.parseAndExecute(args);
}
