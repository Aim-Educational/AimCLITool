module aim.common.services;

private
{
    import std.traits : ConstOf;
    import jaster.ioc.container, jaster.cli : Shell;
}

interface IAimCliConfig(alias ConfT) : IConfig!(ConstOf!ConfT)
if(is(ConfT == struct))
{
    void edit(void delegate(scope ref ConfT));
}

final class AimCliConfig(alias ConfT) : IAimCliConfig!ConfT
{
    private ConfT _value;
    private string _file;

    void loadFromFile(string confFile)
    {
        import std.string    : replace;
        import std.file      : exists, readText;
        import std.path      : absolutePath, expandTilde, isValidPath;
        import std.exception : enforce;
        import asdf          : deserialize;

        this._file = confFile.replace("\\", "/").expandTilde().absolutePath();
        enforce(this._file.isValidPath, "The path '"~this._file~"' is not valid.");

        Shell.verboseLogf("Loading %s from file: %s", __traits(identifier, ConfT), this._file);
        if(this._file.exists)
            this._value = this._file.readText().deserialize!ConfT();
    }

    override void edit(void delegate(scope ref ConfT) editFunc)
    {
        import std.file : exists, mkdirRecurse, write;
        import std.path : dirName;
        import asdf     : serializeToJson;

        editFunc(this._value);

        if(!this._file.exists)
        {
            Shell.verboseLogf("File does not exist, creating directory path: %s", this._file.dirName);
            mkdirRecurse(this._file.dirName);
        }

        Shell.verboseLogf("Saving %s to file: %s", __traits(identifier, ConfT), this._file);
        write(this._file, this._value.serializeToJson());
    }

    @property
    override ConfT value()
    {
        return this._value;
    }
}

void cliConfigure(alias ConfT)(ServiceCollection services, string confFile)
{
    services.addSingleton!(IAimCliConfig!ConfT, AimCliConfig!ConfT)(
        (scope conf)
        {
            conf.loadFromFile(confFile);
        }
    );
}