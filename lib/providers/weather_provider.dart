import 'dart:async';

import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/weather_data.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

WeatherDay? weatherTodayMax;
WeatherDay? weatherTodayMin;
WeatherDay? weatherTomorrowMax;
WeatherDay? weatherNow;

/// Timer to fetch weather data every 4 hours
Timer? fetchTimer;
Timer? updateTickTimer;

/// Rate limiter for Nominatim API calls (max 1 request per second)
DateTime? _lastNominatimRequest;

class WeatherProvider extends ChangeNotifier {
  WeatherProvider(this.context) {
    init();
    initTimers();
  }

  void init() {
    if (AppCache.weatherData.value != null) {
      final cachedWeatherJson = AppCache.weatherData.value!;
      weatherData = WeatherData.fromJson(jsonDecode(cachedWeatherJson));
      filteredWeather = getFilteredWeather();
      refreshGlobalVariables();
      notifyListeners();
    }
    final lastTimeWeatherFetched = AppCache.lastTimeWeatherFetched.value;
    // if fetched more than 4 hours ago, fetch again
    if (lastTimeWeatherFetched != null) {
      final lastTime =
          DateTime.fromMillisecondsSinceEpoch(lastTimeWeatherFetched);
      final now = DateTime.now();
      final difference = now.difference(lastTime).inMinutes;
      if (difference > 59 && AppCache.userCityName.value != null) {
        fetchWeather(AppCache.userCityName.value!, true);
      }
    }
  }

  void initTimers() {
    fetchTimer?.cancel();
    fetchTimer = Timer.periodic(Duration(hours: 4), (timer) {
      if (AppCache.userCityName.value != null) {
        fetchWeather(AppCache.userCityName.value!, false);
      }
    });
    updateTickTimer?.cancel();
    updateTickTimer = Timer.periodic(Duration(minutes: 50), (timer) {
      refreshGlobalVariables();
      notifyListeners();
    });
  }

  final BuildContext? context;
  WeatherData? weatherData;
  List<WeatherDay> filteredWeather = [];
  bool isLoading = false;

  List<WeatherDay> getFilteredWeather() {
    final list = <WeatherDay>[];
    final allWeatherHourly = weatherData?.getWeatherDays();
    // subtract 1 so we can get current time. Otherwise it will start from +1 hour
    final currentDateTime = DateTime.now().subtract(Duration(hours: 1));
    for (WeatherDay weatherDay in allWeatherHourly ?? []) {
      final date = (weatherDay.date ?? DateTime(1970));
      if (date.isAfter(currentDateTime)) list.add(weatherDay);
    }
    return list;
  }

  void refreshGlobalVariables() {
    weatherTodayMax = null;
    weatherTodayMin = null;
    weatherTomorrowMax = null;
    if (filteredWeather.isNotEmpty) {
      final todayNow = DateTime.now();
      final tomorrow = todayNow.add(Duration(days: 1));

      final todayWeather = filteredWeather
          .where(
            (element) => element.date!.day == todayNow.day,
          )
          .toList();
      final tomorrowWeather = filteredWeather
          .where(
            (element) => element.date!.day == tomorrow.day,
          )
          .toList();
      for (var i = 0; i < todayWeather.length; i++) {
        final weath = todayWeather[i];
        if (weath.date?.hour == todayNow.hour) {
          weatherNow = weath;
          break;
        }
      }

      todayWeather.sort(
          (a, b) => (a.temperature ?? '0').compareTo(b.temperature ?? '0'));
      tomorrowWeather.sort(
          (a, b) => (a.temperature ?? '0').compareTo(b.temperature ?? '0'));
      if (todayWeather.isNotEmpty) {
        weatherTodayMax = todayWeather.first;
        weatherTodayMin = todayWeather.last;
      }

      if (tomorrowWeather.isNotEmpty)
        weatherTomorrowMax = tomorrowWeather.first;
    }
  }

  /// https://api.open-meteo.com/v1/forecast?latitude=35&longitude=139&hourly=temperature_2m,precipitation,weather_code
  Future<WeatherData?> fetchWeather(String cityName,
      [bool notify = false]) async {
    isLoading = true;
    if (notify) notifyListeners();
    final coordinates = await _getCoordinates(cityName);
    final lat = coordinates['latitude'];
    final lon = coordinates['longitude'];
    final isValid = lat != null && lon != null;
    log('Coordinates $cityName: $lat, $lon');
    if (isValid) {
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&hourly=temperature_2m,precipitation,weather_code&forecast_days=2');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppCache.weatherData.value = response.body;
        AppCache.lastTimeWeatherFetched.value =
            DateTime.now().millisecondsSinceEpoch;
        final weather = WeatherData.fromJson(data);
        weatherData = weather;
        filteredWeather = getFilteredWeather();
        refreshGlobalVariables();
        isLoading = false;
        if (notify) notifyListeners();

        return weather;
      } else {
        isLoading = false;
        if (notify) notifyListeners();

        throw Exception('Failed to fetch weather data');
      }
    } else {
      isLoading = false;
      if (notify) notifyListeners();
      throw Exception('Invalid coordinates');
    }
  }

  /// Gets coordinates for a city using Nominatim OpenStreetMap API
  /// Complies with Nominatim usage policy:
  /// - Rate limited to max 1 request per second
  /// - Provides proper User-Agent header
  /// - Data is under ODbL license (requires attribution in UI)
  Future<Map<String, double>> _getCoordinates(String cityName) async {
    // Rate limiting: ensure at least 1 second between requests
    if (_lastNominatimRequest != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastNominatimRequest!);
      if (timeSinceLastRequest.inMilliseconds < 1000) {
        await Future.delayed(Duration(milliseconds: 1000 - timeSinceLastRequest.inMilliseconds));
      }
    }
    _lastNominatimRequest = DateTime.now();

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$cityName&format=json&addressdetails=1&limit=1');
    
    // Proper User-Agent as required by Nominatim usage policy
    final response = await http.get(url, headers: {
      'User-Agent': 'FluentGPT/1.0 (https://github.com/realk/fluent_gpt_app)',
      'Referer': 'https://github.com/realk/fluent_gpt_app',
    });

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
      throw Exception(
          'Failed to fetch coordinates. ${response.statusCode} ${response.body}');
    }
  }
}
