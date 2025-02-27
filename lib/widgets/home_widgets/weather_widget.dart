import 'package:entry/entry.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/weather_data.dart';
import 'package:fluent_gpt/providers/weather_provider.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppCache.userCityName.value?.isEmpty == true) {
      return const SizedBox.shrink();
    }
    if (AppCache.showWeatherWidget.value == false) {
      return const SizedBox.shrink();
    }
    final scrollController = ScrollController();
    final provider = context.watch<WeatherProvider>();
    final isWeatherPresent = provider.filteredWeather.isNotEmpty;
    final weatherDays = provider.filteredWeather;
    return Entry.all(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      delay: const Duration(milliseconds: 500),
      child: SizedBox(
        width: 200,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
          child: Hero(
            tag: 'weatherCard',
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(FluentPageRoute(
                    fullscreenDialog: true,
                    maintainState: false,
                    builder: (ctx) {
                      final size = MediaQuery.sizeOf(context);
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: size.height,
                          height: size.height,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(100),
                          ),
                          child: Center(
                            child: Hero(
                              tag: 'weatherCard',
                              child: Container(
                                width: size.width * 0.9,
                                height: 200,
                                decoration: BoxDecoration(
                                  color:
                                      const Color.fromARGB(233, 95, 132, 235),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: WeatherHorizontalList(
                                    isWeatherPresent: isWeatherPresent,
                                    scrollController: scrollController,
                                    weatherDays: weatherDays),
                              ),
                            ),
                          ),
                        ),
                      );
                    }));
              },
              child: Card(
                borderRadius: BorderRadius.circular(12),
                margin: const EdgeInsets.all(0),
                padding: const EdgeInsets.only(
                    left: 16, right: 16, top: 4, bottom: 8),
                backgroundColor: const Color.fromARGB(233, 95, 132, 235),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Weather in',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(' ${AppCache.userCityName.value}',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Spacer(),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () =>
                                launchUrlString('https://open-meteo.com/'),
                            child: Text(
                              'by Open-Meteo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w100,
                                decoration: TextDecoration.underline,
                                // color: Colors.blue.lighter,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Text('X'),
                          onPressed: () {
                            AppCache.showWeatherWidget.value =
                                !(AppCache.showWeatherWidget.value!);
                          },
                        ),
                      ],
                    ),
                    if (provider.isLoading) const Center(child: ProgressBar()),
                    if (weatherNow != null) ...[
                      WeatherNowCard(),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SqueareIconButton(
                          onTap: () {
                            provider.fetchWeather(
                                AppCache.userCityName.value!, true);
                          },
                          icon: Icon(
                              FluentIcons.arrow_counterclockwise_12_regular),
                          tooltip: 'Refresh',
                        ),
                        const SizedBox(width: 8),
                        Button(
                          onPressed: () =>
                              launchUrlString('https://weatherian.com/'),
                          child: const Text('More'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WeatherNowCard extends StatelessWidget {
  const WeatherNowCard({super.key});
  // final WeatherDay weather;
  static const iconSize = 48.0;

  @override
  Widget build(BuildContext context) {
    final weatherProvider = context.watch<WeatherProvider>();
    final weatherStatus = weatherNow!.weatherStatus;
    final date = weatherNow!.date ?? DateTime(1970);

    final formatter = MediaQuery.of(context).alwaysUse24HourFormat
        ? DateFormat('HH:mm')
        : DateFormat('h:mm a');
    final formattedDate = formatter.format(date);
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (weatherStatus == WeatherCode.clearSky)
          Icon(
            FluentIcons.weather_sunny_20_filled,
            color: Colors.yellow,
            size: iconSize,
          )
        else if (weatherStatus == WeatherCode.partlyCloudy)
          Icon(
            FluentIcons.weather_partly_cloudy_day_20_filled,
            color: Colors.blue,
            size: iconSize,
          )
        else if (weatherStatus == WeatherCode.cloudy)
          Icon(
            FluentIcons.weather_cloudy_20_filled,
            color: Colors.blue,
            size: iconSize,
          )
        else if (weatherStatus == WeatherCode.partlyCloudy)
          Icon(
            FluentIcons.weather_partly_cloudy_day_20_filled,
            color: Colors.yellow,
            size: iconSize,
          )
        else if (weatherStatus == WeatherCode.cloudy)
          Icon(
            FluentIcons.weather_cloudy_20_filled,
            color: Colors.blue,
            size: iconSize,
          )
        else if (weatherStatus == WeatherCode.snow)
          Icon(
            FluentIcons.weather_snow_20_filled,
            color: Colors.blue,
            size: iconSize,
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
            ),
            Text(
              '${weatherNow!.temperature ?? '-'} ${weatherNow!.units}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Text(
          '${weatherNow!.precipitation} mm',
          style: TextStyle(
              color: context.theme.typography.caption?.color?.withAlpha(158)),
        ),
      ],
    );
  }
}

class WeatherHorizontalList extends StatelessWidget {
  const WeatherHorizontalList({
    super.key,
    required this.isWeatherPresent,
    required this.scrollController,
    required this.weatherDays,
  });

  final bool isWeatherPresent;
  final ScrollController scrollController;
  final List<WeatherDay> weatherDays;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
      },
      child: SizedBox(
        height: isWeatherPresent ? 130 : 0,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.only(left: 50),
                scrollDirection: Axis.horizontal,
                itemCount: weatherDays.length,
                itemBuilder: (ctx, i) {
                  final weather = weatherDays[i];
                  final weatherStatus = weather.weatherStatus;
                  final date = weather.date ?? DateTime(1970);

                  final formatter = MediaQuery.of(context).alwaysUse24HourFormat
                      ? DateFormat('yyyy-MM-dd\nHH:mm')
                      : DateFormat('yyyy-MM-dd\nh:mm a');
                  final formattedDate = formatter.format(date);
                  return Card(
                    backgroundColor:
                        i == 0 ? Colors.blue : context.theme.cardColor,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formattedDate,
                          textAlign: TextAlign.center,
                        ),
                        if (weatherStatus == WeatherCode.clearSky)
                          Icon(
                            FluentIcons.weather_sunny_20_filled,
                            color: Colors.yellow,
                          ),
                        if (weatherStatus == WeatherCode.partlyCloudy)
                          Icon(
                            FluentIcons.weather_partly_cloudy_day_20_filled,
                            color: Colors.blue,
                          ),
                        if (weatherStatus == WeatherCode.cloudy)
                          Icon(
                            FluentIcons.weather_cloudy_20_filled,
                            color: Colors.blue,
                          ),
                        if (weatherStatus == WeatherCode.foggy)
                          Icon(
                            FluentIcons.weather_fog_20_filled,
                            color: Colors.teal,
                          ),
                        if (weatherStatus == WeatherCode.partlyCloudy)
                          Icon(
                            FluentIcons.weather_partly_cloudy_day_20_filled,
                            color: Colors.yellow,
                          ),
                        if (weatherStatus == WeatherCode.rain)
                          Icon(
                            FluentIcons.weather_rain_20_filled,
                            color: Colors.blue,
                          ),
                        if (weatherStatus == WeatherCode.snow)
                          Icon(
                            FluentIcons.weather_snow_20_filled,
                            color: Colors.blue,
                          ),
                        Text('${weather.precipitation} mm'),
                        Text('${weather.temperature}${weather.units}'),
                      ],
                    ),
                  );
                }),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    scrollController.animateTo(
                      scrollController.offset + 150,
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(204),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(FluentIcons.arrow_right_20_filled),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    scrollController.animateTo(
                      scrollController.offset - 150,
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(204),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(FluentIcons.arrow_left_20_filled),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
