// Only actual captured/open polygons are rendered. Preserve holes and partial areas.
Map<String, dynamic> territoryGeoJson(List<dynamic> items) => {
  'type': 'FeatureCollection',
  'features': items.map((raw) {
    final item = raw as Map<String, dynamic>;
    return {
      'type': 'Feature',
      'id': item['cell_id'],
      'properties': {'color': territoryColor(item['state'] as String)},
      'geometry': item['geometry'],
    };
  }).toList(),
};

String territoryColor(String state) => switch (state) {
  'MINE' => '#35E37A',
  'OPEN' => '#FFE066',
  _ => '#FF5964',
};
