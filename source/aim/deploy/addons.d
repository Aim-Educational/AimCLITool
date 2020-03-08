module aim.deploy.addons;

import aim.common, aim.deploy;
import jaster.ioc;

enum AimDeployAddons
{
    ERROR,
    Nginx
}

interface IAimDeployAddonFactory
{
    IAimDeployAddon getAddonForType(AimDeployAddons type);
}

final class AimDeployAddonFactory : IAimDeployAddonFactory
{
    private ServiceScopeAccessor _scope;

    this(ServiceScopeAccessor scope_)
    {
        this._scope = scope_;
    }

    override IAimDeployAddon getAddonForType(AimDeployAddons type)
    {
        auto serviceScope = this._scope.serviceScope;
        final switch(type) with(AimDeployAddons)
        {
            case ERROR: throw new Exception("Nice try");
            case Nginx:
                return Injector.construct!NginxAimDeployAddon(serviceScope);
        }
    }
}

interface IAimDeployAddon
{
    void onAddedToProject();
    void onPreDeploy();
    void onPostDeploy();
}

final class NginxAimDeployAddon : IAimDeployAddon
{
    private static immutable NGINX_TEMPLATE = import("deploy/nginx_server_block.txt");

    private IAimCliConfig!AimDeployConfig _deployConfig;
    private AimCliConfig!Config           _nginxConfig;

    static struct Config
    {
        string email;
    }

    this(IAimCliConfig!AimDeployConfig config)
    {
        this._deployConfig = config;
        this._nginxConfig  = new AimCliConfig!Config(); // No reason to have addon configs as services. Addon implementations should be responsible for themselves here.
        this._nginxConfig.loadFromFile(PATH(DIR_GIT_IGNORE, "addon_nginx.json"));
    }

    override void onPreDeploy()
    {
    }

    override void onAddedToProject()
    {
        import jaster.cli : Shell;

        this._nginxConfig.edit((scope ref conf)
        {
            conf.email = Shell.getInputNonEmptyString("Email for certs: ");
        });
    }

    override void onPostDeploy()
    {
        import std.conv   : to;
        import std.file   : write;
        import std.format : format;
        import std.array  : replace;
        import jaster.cli : Shell;
        import aim.common : Templater;

        Shell.verboseLogfln("Creating NGINX server block file.");
        auto nginxFile = this.createNginxFilePath(this._deployConfig.value.name);
        write(
            nginxFile, 
            Templater.resolveTemplate(
                [
                    "$DOMAIN": this._deployConfig.value.domain,
                    "$PORT":   this._deployConfig.value.port.to!string
                ],
                NGINX_TEMPLATE
            )
        );

        Shell.verboseLogfln("Linking NGINX server block file to sites-enabled.");
        Shell.executeEnforceStatusPositive(
            "ln -s \"%s\" \"%s\"".format(
                nginxFile,
                nginxFile.replace("sites-available", "sites-enabled")
            )
        );

        Shell.verboseLogfln("Restarting Nginx.");
        Shell.executeEnforceStatusZero("service nginx restart");

        Shell.verboseLogfln("Setting up Certbot.");
        Shell.executeEnforceStatusZero(
            "certbot --nginx -d %s --non-interactive -m %s".format(
                this._deployConfig.value.domain,
                this._nginxConfig.value.email
            )
        );

        Shell.verboseLogfln("Restarting Nginx.");
        Shell.executeEnforceStatusZero("service nginx restart");
    }

    private string createNginxFilePath(string name)
    {
        import std.path : buildNormalizedPath;

        failAssertOnNonLinux();
        return buildNormalizedPath("/etc/nginx/sites-available/", name);
    }
}