
import 'package:flutter/material.dart';

enum ModelFieldDataType { string, number }

class ModelField {
  final String title;
  final bool optional;
  final bool delay;
  ModelFieldDataType type;
  String groupId;

  ModelField({
    @required this.title,
    @required this.optional,
    @required this.delay,
    this.type,
    this.groupId
  });

  @override
  String toString() {
    return 'ModelField { title: $title, type: $type }';
  }
}

class Model {
  final String title;
  final List<ModelField> properties;
  String id;

  Model({
    @required this.title,
    @required this.properties,
    this.id
  });

  @override
  String toString() {
    return 'Model { title: $title, properties: $properties ';
  }
}

class Group {
  final List<String> members;
  final String id;

  Group({
    @required this.members,
    @required this.id
  });

  @override
  String toString() {
    return 'Group $id with members $members';
  }
}

class Record {
  final String modelId;
  final String modelTitle;
  final Map<String, dynamic> properties;
  DateTime checkoutTime;
  String id;

  Record({
    @required this.modelId,
    @required this.modelTitle,
    @required this.properties,
    this.checkoutTime,
    this.id
  });

  @override
  String toString() {
    return 'Record { id: $id, modelId: $modelId, modelTitle: $modelTitle, properties: $properties, checkout: $checkoutTime} ';
  }
}
