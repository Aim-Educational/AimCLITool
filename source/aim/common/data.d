module aim.common.data;

private
{
    import asdf;
}

enum GenericFileVersion
{
    v1
}

enum NO_PREVIOUS_VERSION{na};

mixin template VersionedData(alias MyVersion, alias PreviousVersion)
if(is(typeof(MyVersion) == enum)
|| is(typeof(PreviousVersion) == struct) || is(PreviousVersion == NO_PREVIOUS_VERSION)
)
{
    alias ThisType    = typeof(this);
    alias VersionEnum = typeof(MyVersion);
    alias ThisVersion = MyVersion;

    static assert(
        is(PreviousVersion == NO_PREVIOUS_VERSION)  
     || __traits(compiles, {ThisType t; t.upgrade(PreviousVersion.init);}),

        "This struct is missing this function: `void upgrade(const "~PreviousVersion.stringof~")`"
    );

    static struct FileVersionStruct
    {
        VersionEnum fileVersion;
    }

    VersionEnum fileVersion = MyVersion;

    static if(!__traits(hasMember, ThisType, "fromFile"))
    static ThisType fromFile(string path)
    {
        import std.exception : enforce;

        auto ver = genericFromFile!FileVersionStruct(path);
        enforce(cast(int)ver.fileVersion <= ThisVersion, 
            "The file '"~path~"' is of a newer version than this build was compiled for."
        );

        static if(!is(PreviousVersion == NO_PREVIOUS_VERSION))
        {
            if(ver.fileVersion < ThisVersion)
            {
                ThisType toReturn;
                PreviousVersion toUpgrade = PreviousVersion.fromFile(path);
                
                toReturn.upgrade(toUpgrade);
                return toReturn;
            }
        }

        return genericFromFile!ThisType(path);
    }

    static if(!__traits(hasMember, ThisType, "toFile"))
    void toFile(string path)
    {
        genericToFile(path, this);
    }

    static ThisType createOrGetFromFile(string path)
    {
        import std.file : exists;

        if(!path.exists)
        {
            ThisType t;
            t.toFile(path);
            return t;
        }

        return ThisType.fromFile(path);
    }
}

T genericFromFile(T)(string path)
{
    import std.file  : readText;
    import std.array : replace;

    return path.replace('\\', '/').readText().deserialize!T();
}

void genericToFile(T)(string path, T value)
{
    import std.path  : dirName;
    import std.file  : write, mkdirRecurse;
    import std.array : replace;

    path = path.replace('\\', '/');
    path.dirName.mkdirRecurse();
    path.write(value.serializeToJsonPretty());
}