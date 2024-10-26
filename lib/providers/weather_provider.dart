import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/weather_data.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

WeatherDay? weatherTodayMax;
WeatherDay? weatherTodayMin;
WeatherDay? weatherTomorrowAvg;

class WeatherProvider extends ChangeNotifier {
  WeatherProvider(this.context) {
    init();
  }

  void init() {
    if (AppCache.weatherData.value != null) {
      final cachedWeatherJson = AppCache.weatherData.value!;
      weatherData = WeatherData.fromJson(jsonDecode(cachedWeatherJson));
      filteredWeather = getFilteredWeather();
      refreshGlobalVariables();
      notifyListeners();
    }
  }

  final BuildContext? context;
  WeatherData? weatherData;
  List<WeatherDay> filteredWeather = [];
  bool isLoading = false;

  List<WeatherDay> getFilteredWeather() {
    final list = <WeatherDay>[];
    final allWeatherHourly = weatherData?.getWeatherDays();
    final currentDateTime = DateTime.now();
    for (var weatherDay in allWeatherHourly ?? []) {
      final dateString = (weatherDay.date ?? '1970-01-01T00:00:00Z');
      final date = DateTime.parse(dateString);
      if (currentDateTime.isBefore(date)) {
        list.add(weatherDay);
      }
    }
    return list;
  }

  void refreshGlobalVariables() {
    weatherTodayMax = null;
    weatherTodayMin = null;
    weatherTomorrowAvg = null;
    if (filteredWeather.isNotEmpty) {
      final today = DateTime.now();
      final tomorrow = today.add(Duration(days: 1));
      final todayDate = DateFormat('yyyy-MM-dd').format(today);
      final tomorrowDate = DateFormat('yyyy-MM-dd').format(tomorrow);
      final todayWeather = filteredWeather
          .where(
            (element) => element.date!.contains(todayDate),
          )
          .toList();
      final tomorrowWeather = filteredWeather
          .where(
            (element) => element.date!.contains(tomorrowDate),
          )
          .toList();

      todayWeather.sort(
          (a, b) => (a.temperature ?? '0').compareTo(b.temperature ?? '0'));

      num avg = 0;
      num? precipitation;
      String tomorrowUnits = '';
      num tomorrowWeatherCode = 0;
      // get avg temperature for tomorrow
      for (var weather in tomorrowWeather) {
        final temp = double.tryParse(weather.temperature ?? '0');
        final prec = weather.precipitation;
        if (temp != null) {
          avg += temp;
        }
        if (precipitation != null && prec != null) precipitation += prec;
      }
      if (tomorrowWeather.isNotEmpty) {
        avg = avg / tomorrowWeather.length;
        tomorrowUnits = tomorrowWeather.first.units ?? '';
        tomorrowWeatherCode = tomorrowWeather.first.weatherCode ?? 0;
      }
      weatherTodayMax = todayWeather.first;
      weatherTodayMin = todayWeather.last;
      weatherTomorrowAvg = WeatherDay(
        date: tomorrowDate,
        temperature: avg.toStringAsFixed(0),
        units: tomorrowUnits,
        weatherCode: tomorrowWeatherCode,
        precipitation: precipitation,
      );
    }
  }

  /// https://api.open-meteo.com/v1/forecast?latitude=35&longitude=139&hourly=temperature_2m,precipitation,weather_code
  /// "forecast_days": 3,
  /// "precipitation",
  /// "weather_code"
  Future<WeatherData?> fetchWeather(String cityName) async {
    isLoading = true;
    notifyListeners();
    final coordinates = await _getCoordinates(cityName);
    final lat = coordinates['latitude'];
    final lon = coordinates['longitude'];
    final isValid = lat != null && lon != null;
    log('Coordinates $cityName: $lat, $lon');
    if (isValid) {
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&hourly=temperature_2m,precipitation,weather_code&forecast_days=3');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppCache.weatherData.value = response.body;
        final weather = WeatherData.fromJson(data);
        weatherData = weather;
        filteredWeather = getFilteredWeather();
        refreshGlobalVariables();
        isLoading = false;
        notifyListeners();
        return weather;
      } else {
        isLoading = false;
        notifyListeners();
        throw Exception('Failed to fetch weather data');
      }
    } else {
      isLoading = false;
      notifyListeners();
      throw Exception('Invalid coordinates');
    }
  }

  Future<Map<String, double>> _getCoordinates(String cityName) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$cityName&format=json&addressdetails=1&limit=1');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);
        return {'latitude': lat, 'longitude': lon};
      } else {
        throw Exception('No coordinates found for the city: $cityName');
      }
    } else {
      throw Exception('Failed to fetch coordinates');
    }
  }
}
