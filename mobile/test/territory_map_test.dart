import 'package:flutter_test/flutter_test.dart';
import 'package:runova/features/territories/data/territory_geojson.dart';

void main() {
  test(
    'only owned or open shapes supplied by server are drawn, no preset grid',
    () {
      expect(territoryGeoJson([])['features'], isEmpty);
      expect(territoryColor('MINE'), '#35E37A');
      expect(territoryColor('TAKEN'), '#FF5964');
      expect(territoryColor('OPEN'), '#FFE066');
    },
  );
  test(
    'partial polygons and holes are preserved instead of filling owned land',
    () {
      final shape = {
        'type': 'MultiPolygon',
        'coordinates': [
          [
            [
              [0, 0],
              [4, 0],
              [4, 4],
              [0, 4],
              [0, 0],
            ],
            [
              [1, 1],
              [1, 2],
              [2, 2],
              [2, 1],
              [1, 1],
            ],
          ],
        ],
      };
      final collection = territoryGeoJson([
        {'cell_id': 'area-one', 'state': 'OPEN', 'geometry': shape},
      ]);
      final feature = (collection['features'] as List).single;
      expect(feature['geometry'], same(shape));
      expect(feature['properties']['color'], '#FFE066');
    },
  );
}
