import 'package:chopper/chopper.dart';

part 'weather_forecast_service.chopper.dart';

@ChopperApi(baseUrl: '/weatherForecast')
abstract class WeatherForecastService extends ChopperService {
  static WeatherForecastService create([ChopperClient chopperClient]) =>
      _$WeatherForecastService(chopperClient);

  @Get()
  Future<Response<List<Map<dynamic, dynamic>>>> getAllWeatherForecasts();
}
