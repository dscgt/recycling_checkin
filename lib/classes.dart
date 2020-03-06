
import 'package:flutter/material.dart';

enum DataType { string, number }

/// DataProperty transformed for forms.
class PropertyEntry {
  final TextEditingController controller;
  DataType type;

  PropertyEntry({
    @required this.controller,
    @required this.type,
  });
}

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
  String id;

  Record({
    this.category,
    this.properties,
    this.checkoutTime,
    this.id
  });

  @override
  String toString() {
    return 'Record { id: $id, category: $category, properties: $properties, checkout: $checkoutTime} ';
  }
}
