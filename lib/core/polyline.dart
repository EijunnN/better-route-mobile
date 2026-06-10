import 'package:latlong2/latlong.dart';

/// Decodifica un polyline en formato Google (el que devuelve OSRM vía
/// VROOM, precisión 5) a una lista de puntos. Es la geometría REAL por
/// calles de la ruta — sin esto los mapas unían las paradas con líneas
/// rectas.
List<LatLng> decodePolyline(String encoded, {int precision = 5}) {
  final coordinates = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;
  final factor = 1 / _pow10(precision);

  while (index < encoded.length) {
    var shift = 0;
    var result = 0;
    int byte;

    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

    shift = 0;
    result = 0;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

    coordinates.add(LatLng(lat * factor, lng * factor));
  }

  return coordinates;
}

int _pow10(int exp) {
  var out = 1;
  for (var i = 0; i < exp; i++) {
    out *= 10;
  }
  return out;
}
