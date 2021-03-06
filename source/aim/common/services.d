module aim.common.services;

private
{
    import std.traits : ConstOf;
    import jaster.ioc, jaster.cli : Shell;
}

interface IAimCliConfig(alias ConfT)
if(is(ConfT == struct))
{
    void edit(void delegate(scope ref ConfT));
    void reload();

    @property
    ConfT value();
}

interface IFileDownloader
{
    void downloadStreaming(string url, string outputFile);   
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

        Shell.verboseLogfln("Loading %s from file: %s", __traits(identifier, ConfT), this._file);
        if(this._file.exists)
            this._value = this._file.readText().deserialize!ConfT();
    }

    override void edit(void delegate(scope ref ConfT) editFunc)
    {
        import std.file : exists, mkdirRecurse, write;
        import std.path : dirName;
        import asdf     : serializeToJsonPretty;

        editFunc(this._value);

        if(!this._file.exists)
        {
            Shell.verboseLogfln("File does not exist, creating directory path: %s", this._file.dirName);
            mkdirRecurse(this._file.dirName);
        }

        Shell.verboseLogfln("Saving %s to file: %s", __traits(identifier, ConfT), this._file);
        write(this._file, this._value.serializeToJsonPretty());
    }

    override void reload()
    {
        this.loadFromFile(this._file);
    }

    @property
    override ConfT value()
    {
        return this._value;
    }
}

ServiceInfo cliConfigure(alias ConfT)(string confFile)
{
    return ServiceInfo.asSingleton!(IAimCliConfig!ConfT, AimCliConfig!ConfT)((ref _)
    {
        auto conf = new AimCliConfig!ConfT();
        conf.loadFromFile(confFile);
        return conf;
    });
}

final class FileDownloader : IFileDownloader
{
    override void downloadStreaming(string url, string outputFile)
    {
        import vibe.inet.urltransfer : download;

        download(url, outputFile);
    }   
}