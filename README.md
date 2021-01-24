# Flutter with Keycloak

The key idea is connect Flutter on Android and iOS with [Keycloak](https://www.keycloak.org/).

## Keycloak Configuration

Keycloak can be installed in different manner, the example below demonstrates the use with [Docker](https://www.docker.com/) for test.

To work properly, the authentication needs a server that makes the redirection. Here, [OAuth2 Proxy]([Menu](https://oauth2-proxy.github.io/oauth2-proxy/)) is used to do it.

OAuth2 Proxy is an open source reverse proxy that provides authentication using providers like Google and Keycloak.

```bash
docker network create keycloak-network

docker run -d \
    --name mariadb

-e MYSQL_ROOT_PASSWORD=root \
    -e MYSQL_DATABASE=keycloak \
    -e MYSQL_USER=keycloak \
    -e MYSQL_PASSWORD=keycloak \
    --network keycloak-network \
    mariadb

docker container run \
    --name keycloak \
    -p 8090:8080 \
    -e KEYCLOAK_USER=keycloak \
    -e KEYCLOAK_PASSWORD=keycloak \
    -e DB_ADDR=mariadb \
    -e DB_VENDOR=mariadb \
    -e DB_PORT=3306 \
    -e DB_USER=keycloak \
    -e DB_PASSWORD=keycloak \
    -e JDBC_PARAMS='connectTimeout=3600' \
    --network keycloak-network \
    jboss/keycloak

docker container run \
    --name oauth2-proxy \
    -p 4180:4180 \
    -e OAUTH2_PROXY_PROVIDER=keycloak \
    -e OAUTH2_PROXY_CLIENT_ID='oauth2-proxy' \
    -e OAUTH2_PROXY_CLIENT_SECRET='534cf91e-7deb-44db-94e4-e987380af802' \
    -e OAUTH2_PROXY_SSL-INSECURE-SKIP-VERIFY=true \
    -e OAUTH2_PROXY_COOKIE_SECRET='QKgr59Jfgfxw5gTmokq2GQ==' \
    -e OAUTH2_PROXY_COOKIE-SECURE=false \
    -e OAUTH2_PROXY_EMAIL_DOMAINS='*' \
    -e OAUTH2_PROXY_LOGIN-URL='http://keycloak/realms/master/protocol/openid-connect/auth' \
    -e OAUTH2_PROXY_REDEEM-URL='http://keycloak/realms/master/protocol/openid-connect/token' \
    -e OAUTH2_PROXY_VALIDATE-URL='http://keycloak/realms/master/protocol/openid-connect/userinfo' \
    -e OAUTH2_PROXY_KEYCLOAK-GROUP=/admin \
    --network keycloak-network \
    bitnami/oauth2-proxy:latest
```

### Server Configuration

If is used an API server to provide data to the Flutter client, this server needs to connect to Keycloak to validate the token.

The server should to be registered as a `Client`. The `Access Type` used in Keycloak  `Administration Console` needs to be `confidential`.

![](./docs/oauth2_test/docs/server-configuration.png)

For test, `Valid Redirect URIs` and `Web Origins` can use `*`, but can be better wo change it at production.

![](/home/rony/flutter/oauth2_test/docs/server-configuration-2.png)

The server client and `secret` can be copied in the section `Credentials` after save.

### OAuth2 Proxy Configuration

OAuth2 Proxy also is a `Client`, the `Access Type` also is `confidential`.

In the example, the OAuth2 Proxy is `http://oauth2-proxy` because Docker is used. In production this may change.

To work properly, `Root URL`, `Valid Redirect URIs`,  and `Web Origins` needs to be configured.

![](/home/rony/flutter/oauth2_test/docs/oauth2-proxy-configuration.png)

In the `Mappers` section, is needed to create a `Mapper Type` "Group Membership" with `Token Claim Name` "groups".

The complete configuration of OAuth2 Proxy with Keycloak can be found at [OAuth2 Provider Configuration](https://oauth2-proxy.github.io/oauth2-proxy/docs/configuration/oauth_provider#keycloak-auth-provider)).

![](/home/rony/flutter/oauth2_test/docs/oauth2-proxy-configuration-2.png)

![](/home/rony/flutter/oauth2_test/docs/oauth2-proxy-configuration-3.png)

### Client Configuration

Flutter is also a `Client`, the `Access Type` is `confidential`.

For test, `Valid Redirect URIs` and `Web Origins` can be configured with `*` to permit and URL. Can be more secure change it in production.

In the section `OpenID Connect Compatibility Modes` can be enabled the use of refresh tokens.

![](/home/rony/flutter/oauth2_test/docs/client-configuration.png)

## Token Validation in the API

The example below shows ASP.NET Core configured to request to Keycloak validate the tokens. Othe languagues and frameworks can be used.

The NuGet package required are  [Microsoft.AspNetCore.Authentication.JwtBearer](https://www.nuget.org/packages/Microsoft.AspNetCore.Authentication.JwtBearer):

The code below needs to be put in `Startup.cs`:

```csharp
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.HttpsPolicy;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

namespace KeycloakTestApi
{
    public class Startup
    {
        // ...

        // This method gets called by the runtime. Use this method to add services to the container.
        public void ConfigureServices(IServiceCollection services)
        {
            // ...

            services.AddAuthorization();

            services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
               .AddJwtBearer(jwtBearerOptions =>
           {
               jwtBearerOptions.Authority = Environment.GetEnvironmentVariable("OIDC_AUTHORITY") ?? "http://localhost:8090/auth/realms/master";
               jwtBearerOptions.Audience = Environment.GetEnvironmentVariable("OIDC_CLIENT_ID") ?? "demo-app";
               jwtBearerOptions.IncludeErrorDetails = true;
               jwtBearerOptions.RequireHttpsMetadata = false;
               jwtBearerOptions.TokenValidationParameters = new TokenValidationParameters
               {
                   ValidateAudience = true,
                   ValidAudiences = new[] { "master-realm", "account" },
                   ValidateIssuer = false,
                   ValidateLifetime = false
               };
           });
        }

        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            // ...

            app.UseHttpsRedirection();

            app.UseRouting();

            app.UseAuthentication(); // Required
            app.UseAuthorization(); // Required

            app.UseEndpoints(endpoints =>
                endpoints.MapControllers());
        }
    }
}


```

After configure the authentication, the `controllers` can use the `Authorize` attribute:

```csharp
// ...

namespace KeycloakTestApi.Controllers
{
    [ApiController]
    [Authorize]
    [Route("[controller]")]
    public class WeatherForecastController : ControllerBase
    {
        private static readonly string[] Summaries = new[]
        {
            "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
        };

        private readonly ILogger<WeatherForecastController> _logger;

        public WeatherForecastController(ILogger<WeatherForecastController> logger)
        {
            _logger = logger;
        }

        [HttpGet]
        public IEnumerable<WeatherForecast> Get()
        {
            var rng = new Random();
            return Enumerable.Range(1, 5).Select(index => new WeatherForecast
            {
                Date = DateTime.Now.AddDays(index),
                TemperatureC = rng.Next(-20, 55),
                Summary = Summaries[rng.Next(Summaries.Length)]
            })
            .ToArray();
        }
    }
}


```

## Flutter Client

The example focuses on mobile and not support Flutter web. Only the Android version was tested.

To work without `HTTPS` is needed to use `HttpOverrides` with `badCertificateCallback`.

```dart
class ApplicationHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, __, ___) => true;
  }
}

void main() {
  HttpOverrides.global = ApplicationHttpOverrides();

  runApp(WeatherForecastApplication());
}
```

In the `AndroidManifest.xml` file, is also needed to put `android:usesCleartextTraffic="true"` at `application` tag.

The configuration `android:usesCleartextTraffic` is required to used and IP address without HTTPS. To use and domain like `site.com` without HTTPS, is required to use [network security configuration](https://developer.android.com/training/articles/security-config).

```xml
    <uses-permission android:name="android.permission.INTERNET" />

    <application
        android:icon="@mipmap/ic_launcher"
        android:label="oauth2_test"
        android:usesCleartextTraffic="true">

```

The iOS version can need to configure [App Transport Security](https://guides.codepath.com/ios/App-Transport-Security) (ATS). The use of IP address without domin has a similar limitation to that found on Android. To disable ATS, can be used the XML below at `Info.plist` file.

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key><true/>
</dict>
```

The full example is at the `main.dart` file. The [Chopper](https://pub.dev/packages/chopper) package is not required to the OIDC authentication with Keycloak. 

To display the Keycloak's login page can be used `Navigator` as show below:

```dart
Uri responseUrl;

await Navigator.push(
    context,
    MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) {
          return SafeArea(
            child: Container(
              child: WebView(
                javascriptMode: JavascriptMode.unrestricted,
                initialUrl: authorizationUrl.toString(),
                navigationDelegate: (navigationRequest) {
                  if (navigationRequest.url
                      .startsWith(redirectUrl.toString())) {
                    responseUrl = Uri.parse(navigationRequest.url);
            
                    Navigator.pop(context); // closes the WebView
            
                    return NavigationDecision.prevent;
                  }
                  return NavigationDecision.navigate;
                },
              ),
            ),
          );
        }));
```
