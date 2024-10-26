class WeatherData {
  final double? latitude;
  final double? longitude;
  final double? generationtimeMs;
  final int? utcOffsetSeconds;
  final String? timezone;
  final String? timezoneAbbreviation;
  final double? elevation;
  final HourlyUnits? hourlyUnits;
  final Hourly? hourly;

  WeatherData({
    this.latitude,
    this.longitude,
    this.generationtimeMs,
    this.utcOffsetSeconds,
    this.timezone,
    this.timezoneAbbreviation,
    this.elevation,
    this.hourlyUnits,
    this.hourly,
  });

  List<WeatherDay> getWeatherDays() {
    List<WeatherDay> weatherDays = [];
    if (hourly != null && hourlyUnits != null) {
      for (int i = 0; i < hourly!.time!.length; i++) {
        weatherDays.add(WeatherDay(
          date: hourly!.time![i],
          temperature: hourly!.temperature2m![i].toString(),
          units: hourlyUnits!.temperature2m,
          precipitation: hourly!.precipitation![i],
        ));
      }
    }
    return weatherDays;
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      generationtimeMs: json['generationtime_ms']?.toDouble(),
      utcOffsetSeconds: json['utc_offset_seconds']?.toInt(),
      timezone: json['timezone'],
      timezoneAbbreviation: json['timezone_abbreviation'],
      elevation: json['elevation']?.toDouble(),
      hourlyUnits: json['hourly_units'] != null
          ? HourlyUnits.fromJson(json['hourly_units'])
          : null,
      hourly: json['hourly'] != null ? Hourly.fromJson(json['hourly']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'generationtime_ms': generationtimeMs,
      'utc_offset_seconds': utcOffsetSeconds,
      'timezone': timezone,
      'timezone_abbreviation': timezoneAbbreviation,
      'elevation': elevation,
      'hourly_units': hourlyUnits?.toJson(),
      'hourly': hourly?.toJson(),
    };
  }
}

enum WeatherCode {
  clearSky,
  partlyCloudy,
  cloudy,
  foggy,
  rain,
  snow,
}

class WeatherDay {
  final String? date;
  final String? temperature;
  final String? units;
  final num? precipitation;

  /// WMO weather interpretation codes
  final num? weatherCode;

  /// returns weather name based on WMO weather interpretation codes
  /// 0 clear
  /// 1 Mainly Sunny
  /// 2 Partly Cloudy
  /// 3 Cloudy
  /// 45 Foggy
  /// 48 Rime Fog
  /// 61 Light Rain
  /// 71 Light Snow
  WeatherCode get weatherStatus {
    final code = weatherCode ?? 0;

    if (code == 0) return WeatherCode.clearSky;
    if (code == 1) return WeatherCode.partlyCloudy;
    if (code == 2) return WeatherCode.partlyCloudy;
    if (code == 3) return WeatherCode.cloudy;
    if (code >= 71) return WeatherCode.snow;
    if (code >= 61) return WeatherCode.rain;
    if (code >= 45) return WeatherCode.foggy;

    return WeatherCode.clearSky;
  }

  WeatherDay({
    this.date,
    this.temperature,
    this.units,
    this.precipitation,
    this.weatherCode,
  });

  factory WeatherDay.fromJson(Map<String, dynamic> json) {
    return WeatherDay(
      date: json['date'],
      temperature: json['temperature'],
      units: json['units'],
      precipitation: json['precipitation'],
      weatherCode: json['weather_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'temperature': temperature,
      'units': units,
      'precipitation': precipitation,
      'weather_code': weatherCode,
    };
  }
}

class HourlyUnits {
  final String? time;
  final String? temperature2m;

  HourlyUnits({
    this.time,
    this.temperature2m,
  });

  factory HourlyUnits.fromJson(Map<String, dynamic> json) {
    return HourlyUnits(
      time: json['time'],
      temperature2m: json['temperature_2m'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'temperature_2m': temperature2m,
    };
  }
}

class Hourly {
  final List<String>? time;
  final List<double>? temperature2m;
  final List<num>? precipitation;

  Hourly({
    this.time,
    this.temperature2m,
    this.precipitation,
  });

  factory Hourly.fromJson(Map<String, dynamic> json) {
    return Hourly(
      time: json['time'] != null ? List<String>.from(json['time']) : null,
      temperature2m: json['temperature_2m'] != null
          ? List<double>.from(json['temperature_2m'])
          : null,
      precipitation: json['precipitation'] != null
          ? List<num>.from(json['precipitation'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'temperature_2m': temperature2m,
      'precipitation': precipitation,
    };
  }
}
