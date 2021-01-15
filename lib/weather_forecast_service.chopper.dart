// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weather_forecast_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: always_put_control_body_on_new_line, always_specify_types, prefer_const_declarations
class _$WeatherForecastService extends WeatherForecastService {
  _$WeatherForecastService([ChopperClient client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = WeatherForecastService;

  @override
  Future<Response<List<Map<dynamic, dynamic>>>> getAllWeatherForecasts() {
    final $url = '/weatherForecast';
    final $request = Request('GET', $url, client.baseUrl);
    return client
        .send<List<Map<dynamic, dynamic>>, Map<dynamic, dynamic>>($request);
  }
}
