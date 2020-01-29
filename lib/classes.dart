
enum DataType { string, number }

class DataProperty {
  final String title;
  final DataType type;

  DataProperty({
    this.title,
    this.type
  });

  @override
  String toString() {
    return 'DataProperty { title: $title, type: $type }';
  }
}

class DataCategory {
  final String title;
  final List<DataProperty> properties;

  DataCategory({
    this.title,
    this.properties
  });

  @override
  String toString() {
    return 'DataCategory { title: $title, properties: $properties ';
  }
}
