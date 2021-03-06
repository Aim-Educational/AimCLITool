module aim.deploy.triggers;

import std.datetime;
import aim.common, aim.deploy;
import jaster.ioc, jaster.cli;

enum AimDeployTriggers
{
    ERROR,
    GithubDeployment
}

interface IAimDeployTriggerFactory
{
    IAimDeployTrigger getTriggerForType(AimDeployTriggers type);
}

final class AimDeployTriggerFactory : IAimDeployTriggerFactory
{
    private ServiceScopeAccessor _scope;

    this(ServiceScopeAccessor scope_)
    {
        this._scope = scope_;
    }

    override IAimDeployTrigger getTriggerForType(AimDeployTriggers type)
    {
        auto serviceScope = this._scope.serviceScope;
        final switch(type) with(AimDeployTriggers)
        {
            case ERROR: throw new Exception("Nice try");
            case GithubDeployment:
                return Injector.construct!GithubAimDeployTrigger(serviceScope);
        }
    }
}

interface IAimDeployTrigger
{
    void onAddedToProject();
    bool shouldTriggerDeploy();
    void onPostDeploy(bool success);
}

final class GithubAimDeployTrigger : IAimDeployTrigger
{
    private static immutable REF_REGEX = `refs/.+/(.+)`;
    private static immutable GRAPHQL_GET_DEPLOYMENTS = `
    query($owner:String!, $name:String!) { 
        repository(name:$name,owner:$owner) {
            deployments(orderBy:{field:CREATED_AT, direction:DESC}, first:30){
                nodes{
                    databaseId
                    environment
                    state
                    createdAt
                }
            }
        }
    }`;

    private AimCliConfig!Config           _githubConf;
    private IAimCliConfig!AimDeployConfig _deployConf;

    static struct Config
    {
        string deployToken;
        string repoOwner;
        string repoName;
        string deploymentId;
        string lastDeploymentTime; // The create_at time of the last deployment used. Used so we don't deploy older verisons by mistake.
    }

    this(IAimCliConfig!AimDeployConfig deployConf)
    {
        this._deployConf = deployConf;
        this._githubConf = new AimCliConfig!Config();
        this._githubConf.loadFromFile(PATH(DIR_GIT_IGNORE, "trigger_github_deployment.json"));

        this._githubConf.edit((scope ref conf)
        {
            if(conf.lastDeploymentTime.length == 0)
                conf.lastDeploymentTime = (new SysTime(0)).toISOExtString();
        });
    }

    override void onAddedToProject()
    {
        this._githubConf.edit((scope ref conf)
        {
            conf.deployToken = Shell.getInputNonEmptyString("Deploy Token: ");
            conf.repoOwner   = Shell.getInputNonEmptyString("Repo Owner: ");
            conf.repoName    = Shell.getInputNonEmptyString("Repo Name: ");
        });
    }

    override bool shouldTriggerDeploy()
    {
        import std.algorithm : filter;
        import std.regex     : matchFirst;
        import vibe.data.json;
        import vibe.http.client;

        // Find a deployment that's in the right environment, state, and isn't older than our last deployment.
        Shell.verboseLogfln("Sending GraphQL query to Github");
        auto response = requestHTTP(
            "https://api.github.com/graphql",
            (scope req)
            {
                req.method = HTTPMethod.POST;
                req.headers["Authorization"] = "bearer "~this._githubConf.value.deployToken;
                req.writeJsonBody(
                [
                    "query": Json(GRAPHQL_GET_DEPLOYMENTS),
                    "variables": Json(
                    [
                        "owner": Json(this._githubConf.value.repoOwner),
                        "name":  Json(this._githubConf.value.repoName)
                    ])
                ]);
            }
        ).readJson();

        auto lastDeployTime = SysTime.fromISOExtString(this._githubConf.value.lastDeploymentTime);
        auto nodes = response["data"]["repository"]["deployments"]["nodes"];
        auto firstPendingProduction = nodes.byValue
                                           .filter!(v => v["environment"].to!string == "production" // TODO: This should be a config option.
                                                      && v["state"].to!string       == "PENDING"    // TODO: Arguably this too, but it's less important.
                                                      && SysTime.fromISOExtString(v["createdAt"].to!string()[0..$-1] ~ ".0000000" ~ "Z") > lastDeployTime
                                           );

        if(firstPendingProduction.empty)
        {
            Shell.verboseLogfln("No pending, in-date deployments found");
            this._githubConf.edit((scope ref conf){conf.deploymentId = null;});
            return false;
        }

        const deployment = firstPendingProduction.front;
        const databaseId = deployment["databaseId"].to!string();
        Shell.verboseLogfln("Pending deployment found, id: %s", databaseId);

        this._githubConf.edit((scope ref conf)
        {
            conf.deploymentId       = databaseId; // So onPostDeploy knows what ID to use.
            conf.lastDeploymentTime = deployment["createdAt"].to!string()[0..$-1] ~ ".0000000" ~ "Z";
        });

        // Find the ref, as that's being used as the image tag.
        Shell.verboseLogfln("Finding deployment ref");
        response = requestHTTP(
            this.getDeploymentUrl(),
            (scope req)
            {
                req.method = HTTPMethod.GET;
                req.headers["Authorization"] = "bearer "~this._githubConf.value.deployToken;
            }
        ).readJson();

        auto gitRef = response["ref"].to!string();
        Shell.verboseLogfln("Ref: %s", gitRef);

        // Try to match "refs/[anything]/([anything, except we want to capture this part]) and use that as the image tag, otherwise use the entire ref.
        auto match = matchFirst(gitRef, REF_REGEX);
        auto matchedRef = (!match.empty) ? match.captures[1] : gitRef;
        Shell.verboseLogfln("Ref(Regexed): %s", matchedRef);

        if(this._deployConf.value.projectType == AimDeployConfig.Type.Docker)
        {
            this._deployConf.edit((scope ref conf)
            {
                conf.docker.tagInUse = matchedRef;
            });
        }

        return true;
    }

    override void onPostDeploy(bool success)
    {
        import vibe.http.client;

        Shell.verboseLogfln("Updating deployment status");
        auto response = requestHTTP(
            this.getDeploymentUrl()
           ~"/statuses",
            (scope req)
            {
                req.method = HTTPMethod.POST;
                req.headers["Accept"] = "application/vnd.github.flash-preview+json";
                req.headers["Authorization"] = "bearer "~this._githubConf.value.deployToken;
                req.writeJsonBody(
                [
                    "state":        success ? "success" : "failure",
                    "environment":  "production",
                    "description":  "Deployed by AimCLI"
                ]);
            }
        ).readJson();
    }

    private string getDeploymentUrl()
    {
        return 
            "https://api.github.com"
           ~"/repos"
           ~"/"~this._githubConf.value.repoOwner
           ~"/"~this._githubConf.value.repoName
           ~"/deployments"
           ~"/"~this._githubConf.value.deploymentId;
    }
}