import 'package:flutter_dotenv/flutter_dotenv.dart';

final String mapboxAccessToken =
    dotenv.env['MAPBOX_ACCESS_TOKEN'] ??
    const String.fromEnvironment('MAPBOX_ACCESS_TOKEN', defaultValue: '');
