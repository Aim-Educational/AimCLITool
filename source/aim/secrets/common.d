module aim.secrets.common;

private
{
    import std.exception : enforce;
    import jaster.cli.core, jaster.cli.udas, jaster.cli.helptext;
    import aim.secrets.data, aim.common.data;
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
            def.fileVersion = GenericFileVersion.v1;
            def.toFile(path);

            Common.openConfigSafeModify((ref conf)
            {
                conf.definitionFiles ~= path.relativePath;
            });

            return def;
        }

        SecretsDefinition[] readAllDefinitionFiles()
        {
            import std.algorithm : map;
            import std.array     : array;

            return SecretsConfig.createOrGetFromFile(CONFIG_FILE_LOCATION)
                                .definitionFiles
                                .map!(f => SecretsDefinition.fromFile(f))
                                .array;
        }

        void openConfigSafeModify(void delegate(ref SecretsConfig) operation)
        {
            if(Common._configRefCount == 0)
            {
                Common._configRefCount++;
                Common._configBeingModified = SecretsConfig.createOrGetFromFile(CONFIG_FILE_LOCATION);
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