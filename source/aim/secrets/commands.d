module aim.secrets.commands;

private
{
    import std.stdio     : writeln, writefln;
    import std.exception : enforce;
    import std.exception : assumeUnique;
    import std.file      : exists;
    import std.path      : buildNormalizedPath;
    import jaster.cli.core, jaster.cli.udas, jaster.cli.helptext;
    import aim.secrets.data, aim.secrets.common;
}

const DEF_FOLDER_PATH       = ".aim/git_keep/secrets/";
const DEFAULT_DEF_FILE_PATH = DEF_FOLDER_PATH ~ "default.json";

@Command("define", "Defines a new/existing definition into the specified (or default) definition file.")
struct Define
{
    @CommandPositionalArg(0, "key", "The definition's key/name.")
    string key;

    @CommandPositionalArg(1, "value", "The definition's description.")
    string description;

    @CommandNamedArg("f|def-file", "The name of the definition file to modify. Leave empty for the default.")
    Nullable!string definitionFile;

    @CommandNamedArg("c|create-def-file", "If the definition file does not exist, create it.")
    Nullable!bool createDefFile;
    
    @CommandNamedArg("o|optional", "Marks this definition as being optional.")
    Nullable!bool isOptional;

    void onExecute()
    {
        // Throw, create, or get the definition file.
        auto defFilePath = this.definitionFile.get(DEFAULT_DEF_FILE_PATH).assumeUnique; // Why does `get` return a const(char)[]??
             defFilePath = defFilePath.buildNormalizedPath();
        SecretsDefinition defFile;
        if(defFilePath.exists)
            defFile = SecretsDefinition.fromFile(defFilePath); 
        else
        {
            enforce(
                this.createDefFile.get(false), 
                "The definition file '"~defFilePath~"' doesn't exist, and the --create-def-file arg wasn't passed. Can't continue."
            );

            defFile = Common.createDefinitionFile(defFilePath);
        }

        // Add the definition
        defFile.values[this.key] = SecretsDefinition.Value(this.description, cast(ArgIsOptional)this.isOptional.get(false));
        defFile.toFile(defFilePath);
    }
}

@Command("list-defines", "List all definitions, excluding their values, from all known definition files.")
struct ListDefines
{
    int onExecute()
    {
        auto text = new HelpTextBuilderTechnical();
        text.addSection("Definitions");
        foreach(defFile; Common.readAllDefinitionFiles())
        {
            text.modifySection("Definitions")
                .addContent(Common.defListToArgInfo(defFile.values.byKeyValue));
        }

        writeln(text.toString());
        return 0;
    }
}

@Command("verify", "Verifies that all required definitions have been given values.")
struct Verify
{
    int onExecute()
    {
        import std.algorithm : map, filter, any;

        bool areAnyMissing = false;
        auto text = new HelpTextBuilderTechnical();
        text.addSection("Missing");

        auto store = Common.createOrGetStoreFile();
        foreach(defList; Common.readAllDefinitionFiles()
                               .map!(f => f.values.byKeyValue)
                               .filter!(kvrange => kvrange.any!(kv => (kv.key in store.values) is null))
        )
        {
            areAnyMissing = true;
            text.modifySection("Missing")
                .addContent(Common.defListToArgInfo(defList));
        }

        if(areAnyMissing)
        {
            writeln(text.toString());
            return -2;
        }
        else
        {
            writeln("Verification successful.");
            return 0;
        }
    }
}

@Command("set-value", "Sets the value for a defintion.")
struct SetValue
{
    @CommandPositionalArg(0, "Key", "The key/name of the definition to set the value of.")
    string key;

    @CommandPositionalArg(1, "Value", "The value to give the definition.")
    string value;

    void onExecute()
    {
        import std.exception : enforce;

        enforce(Common.doesDefinitionKeyExist(this.key),
            "There is no definition called '"~this.key~"'"
        );

        auto store = Common.createOrGetStoreFile();
        store.values[this.key] = value;
        store.toFile(STORE_FILE_LOCATION);
    }
}

@Command("get-value", "Gets the value for a definition.")
struct GetValue
{
    @CommandPositionalArg(0, "Key", "The key/name of the definition to get the value of.")
    string key;

    void onExecute()
    {
        import std.exception : enforce;

        enforce(Common.doesDefinitionKeyExist(this.key),
            "There is no definition called '"~this.key~"'"
        );

        auto store = Common.createOrGetStoreFile();
        auto ptr   = (this.key in store.values);

        enforce(ptr !is null, "The definition '"~this.key~"' exists, but hasn't been given a value.");
        writeln(*ptr);
    }
}