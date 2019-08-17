module aim.deploy.commands;

private
{
    import jaster.cli;
    import aim.common, aim.deploy;
}

@Command("deploy pack", "Creates a package that can then be deployed to a server.")
final class AimDeployPack : BaseCommand
{
    private IAimDeployPacker _packer;

    @CommandNamedArg("d|data-dir", "The directory containing the package's data.")
    string directory;

    @CommandNamedArg("a|aim-dir", "The path to the '.aim' directory. Use '-a none' if there is no '.aim' directory.")
    string aimDirectory;

    @CommandNamedArg("o|out-file", "The output file name. [Default="~IAimDeployPacker.DEFAULT_PACKAGE_NAME~"]")
    Nullable!string outFile;

    this(IAimDeployPacker packer)
    {
        assert(packer !is null);
        this._packer = packer;
    }

    override int onExecute()
    {
        import std.exception : assumeUnique;
        super.onExecute();
        this._packer.pack(this.outFile.get(IAimDeployPacker.DEFAULT_PACKAGE_NAME).assumeUnique, this.directory, this.aimDirectory);

        return 0;
    }
}