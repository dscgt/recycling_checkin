
enum DataType { string, number }

class DataProperty {
  final String title;
  DataType type;

  DataProperty({
    this.title,
    this.type,
  });

  @override
  String toString() {
    return 'DataProperty { title: $title, type: $type }';
  }
}

class DataCategory {
  final String title;
  final List<DataProperty> properties;
  String id;

  DataCategory({
    this.title,
    this.properties,
    this.id
  });

  @override
  String toString() {
    return 'DataCategory { title: $title, properties: $properties ';
  }
}

class Record {
  final String category;
  final Map<String, dynamic> properties;
  DateTime checkoutTime;
  DateTime checkinTime;
  String id;

  Record({
    this.category,
    this.properties,
    checkinTime,
    checkoutTime,
    this.id
  }) {
    // don't allow for checkinTimes unless a checkoutTime is also specified
    if (checkinTime != null && checkoutTime == null) {
      throw new RangeError('Record with a check-in time cannot be created without a check-out time.');
    }
    this.checkoutTime = checkoutTime;
    this.checkinTime = checkinTime;
  }

  @override
  String toString() {
    return 'Record { id: $id, category: $category, properties: $properties, checkout: $checkoutTime, checkin: $checkinTime} ';
  }
}
