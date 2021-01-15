import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:oauth2_test/weather_forecast_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

ChopperClient chopperClient;

class ApplicationHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, __, ___) => true;
  }
}

void main() {
  HttpOverrides.global = ApplicationHttpOverrides();

  Logger.root.onRecord.listen((record) {
    if (kReleaseMode) {
      print('[${record.level.name}] ${record.time}: ${record.message}');
    }
  });

  runApp(WeatherForecastApplication());
}

class WeatherForecastApplication extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter with OAuth 2'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final logger = Logger('$_MyHomePageState');

  Future<Response<List<Map<dynamic, dynamic>>>> _allWeatherForecasts;

  @override
  void initState() {
    super.initState();

    // Enable hybrid composition.
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
  }

  /// Either load an OAuth2 client from saved credentials or authenticate a new
  /// one.
  Future<oauth2.Client> createClient() async {
    final authorizationEndpoint = Uri.parse(
        'http://10.0.2.2:8090/auth/realms/master/protocol/openid-connect/auth');
    final tokenEndpoint = Uri.parse(
        'http://10.0.2.2:8090/auth/realms/master/protocol/openid-connect/token');

    // The authorization server will issue each client a separate client
    // identifier and secret, which allows the server to tell which client
    // is accessing it. Some servers may also have an anonymous
    // identifier/secret pair that any client may use.
    //
    // Note that clients whose source code or binary executable is readily
    // available may not be able to make sure the client secret is kept a
    // secret. This is fine; OAuth2 servers generally won't rely on knowing
    // with certainty that a client is who it claims to be.
    final identifier = 'flutter-client';
    final secret = '28d97248-7bcc-4382-86de-d2311c74669e';

    // This is a URL on your application's server. The authorization server
    // will redirect the resource owner here once they've authorized the
    // client. The redirection will include the authorization code in the
    // query parameters.
    final redirectUrl = Uri.parse('http://10.0.2.2:4180/oauth2/callback');

    var grant = oauth2.AuthorizationCodeGrant(
      identifier,
      authorizationEndpoint,
      tokenEndpoint,
      secret: secret,
    );

    // A URL on the authorization server (authorizationEndpoint with some additional
    // query parameters). Scopes and state can optionally be passed into this method.
    var authorizationUrl = grant.getAuthorizationUrl(redirectUrl);

    Uri responseUrl;

    await Navigator.push(
        context,
        MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) {
              // Redirect the resource owner to the authorization URL. Once the resource
              // owner has authorized, they'll be redirected to `redirectUrl` with an
              // authorization code. The `redirect` should cause the browser to redirect to
              // another URL which should also have a listener.
              return SafeArea(
                child: Container(
                  child: WebView(
                    javascriptMode: JavascriptMode.unrestricted,
                    initialUrl: authorizationUrl.toString(),
                    navigationDelegate: (navigationRequest) {
                      if (navigationRequest.url
                          .startsWith(redirectUrl.toString())) {
                        responseUrl = Uri.parse(navigationRequest.url);
                        print('Response URL: $responseUrl}');
                        Navigator.pop(context);
                        return NavigationDecision.prevent;
                      }
                      return NavigationDecision.navigate;
                    },
                  ),
                ),
              );
            }));

    // Once the user is redirected to `redirectUrl`, pass the query parameters to
    // the AuthorizationCodeGrant. It will validate them and extract the
    // authorization code to create a new Client.
    return grant.handleAuthorizationResponse(responseUrl.queryParameters);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: FutureBuilder<Response<List<Map>>>(
        future: _allWeatherForecasts,
        builder: (_, weatherForecastsSnapshot) {
          print('Weather forecasts snapshot: $weatherForecastsSnapshot');

          if (weatherForecastsSnapshot.connectionState !=
                  ConnectionState.done ||
              !weatherForecastsSnapshot.hasData) {
            return Center(
              child: CircularProgressIndicator.adaptive(),
            );
          }

          if (weatherForecastsSnapshot.hasError) {
            logger.warning(weatherForecastsSnapshot.error);

            return Center(
              child: Text(
                  'Unfortunately, an error has happened and will be needed to try another time.'),
            );
          }

          final weatherForecasts = weatherForecastsSnapshot.data.body;
          return ListView.builder(
            itemCount: weatherForecasts.length,
            itemBuilder: (_, int index) {
              final weatherForecast = weatherForecasts[index];
              final date = DateTime.tryParse(weatherForecast['date']);

              return ListTile(
                title: Text('${weatherForecast['summary']}'),
                subtitle: Text('${date.day}/${date.month}'),
                trailing: Text(
                  '${weatherForecast['temperatureC']} °C',
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.https),
        onPressed: () async {
          final httpClient = await createClient();

          chopperClient = ChopperClient(
            client: httpClient,
            baseUrl: 'https://10.0.2.2:5001',
            converter: JsonConverter(),
            services: [
              WeatherForecastService.create(),
            ],
          );

          final weatherForecastService =
              chopperClient.getService<WeatherForecastService>();
          setState(() {
            _allWeatherForecasts =
                weatherForecastService.getAllWeatherForecasts();
            print('Weather forecasts: $_allWeatherForecasts');
          });
        },
      ),
    );
  }
}
