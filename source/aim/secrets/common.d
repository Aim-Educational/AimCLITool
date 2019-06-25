module aim.secrets.common;

private
{
    import std.exception : enforce;
    import jaster.cli.core, jaster.cli.udas, jaster.cli.helptext;
    import aim.secrets.data;
}

const CONFIG_FILE_LOCATION = ".aim/git_keep/secrets_config.json";
const STORE_FILE_LOCATION  = ".aim/git_ignore/secrets_store.json";

final static abstract class Common
{
    private static
    {
        Nullable!SecretsConfig _configBeingModified;
        size_t                 _configRefCount;
    }

    public static
    {
        SecretsDefinition createDefinitionFile(string path)
        {
            import std.path : relativePath;
            import std.file : exists;

            enforce(!path.exists, "The path '"~path~"' already exists.");

            SecretsDefinition def;
            def.fileVersion = SecretsDefinition.Version.v1;
            def.toFile(path);

            Common.openConfigReadWrite((ref conf)
            {
                conf.definitionFiles ~= path.relativePath;
            });

            return def;
        }

        SecretsDefinition[] readAllDefinitionFiles()
        {
            import std.algorithm : map;
            import std.array     : array;

            return Common.createOrGetConfigFile()
                         .definitionFiles
                         .map!(f => SecretsDefinition.fromFile(f))
                         .array;
        }

        SecretsStore createOrGetStoreFile()
        {
            import std.file : exists;

            if(STORE_FILE_LOCATION.exists)
                return SecretsStore.fromFile(STORE_FILE_LOCATION);

            SecretsStore config;
            config.fileVersion = SecretsStore.Version.v1;
            config.toFile(STORE_FILE_LOCATION);

            return config;
        }

        SecretsConfig createOrGetConfigFile()
        {
            import std.file : exists;

            if(CONFIG_FILE_LOCATION.exists)
                return SecretsConfig.fromFile(CONFIG_FILE_LOCATION);

            SecretsConfig config;
            config.fileVersion = SecretsConfig.Version.v1;
            config.toFile(CONFIG_FILE_LOCATION);

            return config;
        }

        SecretsConfig openConfigReadOnly()
        {
            return Common.createOrGetConfigFile();
        }

        void openConfigReadWrite(void delegate(ref SecretsConfig) operation)
        {
            if(Common._configRefCount == 0)
            {
                Common._configRefCount++;
                Common._configBeingModified = Common.createOrGetConfigFile();
            }
            scope(exit)
            {
                Common._configRefCount--;
                if(Common._configRefCount == 0)
                {
                    Common._configBeingModified.toFile(CONFIG_FILE_LOCATION);
                    Common._configBeingModified.nullify;
                }
            }

            operation(Common._configBeingModified);
        }

        HelpSectionArgInfoContent defListToArgInfo(KVRange)(KVRange defList)
        {
            import std.algorithm : map;
            import std.array     : array;

            return new HelpSectionArgInfoContent(
                defList.map!(kv => HelpSectionArgInfoContent.ArgInfo([kv.key], kv.value.description, kv.value.isOptional))
                       .array,
                AutoAddArgDashes.no
            );
        }

        bool doesDefinitionKeyExist(string key)
        {
            import std.algorithm : map, any;

            return Common.readAllDefinitionFiles()
                         .map!(f => f.values.byKeyValue)
                         .any!(kvr => kvr.any!(kv => kv.key == key));
        }
    }
}