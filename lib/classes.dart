
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:recycling_checkin/utils.dart';

enum ModelFieldDataType { string, number, select }

class ModelField {
  final String title;
  final bool optional;
  final bool delay;
  final ModelFieldDataType type;
  String groupId;

  ModelField({
    @required this.title,
    @required this.optional,
    @required this.delay,
    this.type,
    this.groupId
  });

  /// Converts a map to a ModelField, using map key-value pairs as
  /// ModelField fields. In the case of null values, optional will default
  /// to false, delay will default to false, and groupId maintains null, while
  /// title and type cannot be null and will likely error. type accepts strings
  /// or ModelFieldDataType. groupId accepts DocumentReference or strings.
  ModelField.fromMap(Map map)
    : title = map['title'],
      optional = map['optional'] ?? false,
      delay = map['delay'] ?? false,
      type = map['type'] is ModelFieldDataType
        ? map['type']
        : stringToModelFieldDataType(map['type']),
      groupId = map['groupId'] is DocumentReference
        ? map['groupId'].documentID
        : map['groupId'];

  @override
  String toString() {
    return 'ModelField { title: $title, type: $type }';
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'optional': optional,
      'delay': delay,
      'type': type,
      'groupId': groupId,
    };
  }
}

class Model {
  final String title;
  List<ModelField> fields;
  String id;

  Model({
    @required this.title,
    @required this.fields,
    this.id
  });

  Model.fromMap(Map map)
    : title = map['title'],
      id = map['id'] {
    try {
      fields = map['fields']
        .map((dynamic m) => ModelField.fromMap(m))
        .toList()
        .cast<ModelField>();
    } catch (e) {
      throw Exception('There was an error creating your Model from a map;'
      + ' provided map is likely malformed. Check that it matches the Model'
      + ' spec. The error was: $e');
    }
  }

  @override
  String toString() {
    return 'Model { title: $title, fields: $fields ';
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'id': id,
      'fields': fields
        .map((ModelField mf) => mf.toMap())
        .toList()
    };
  }
}

class Group {
  final List<String> members;
  String id;

  Group({
    @required this.members,
    @required this.id
  });

  Group.fromMap(Map map)
    : members = map['members']
        .map((dynamic) => dynamic['title']).toList().cast<String>(),
      id = map['id'];

  @override
  String toString() {
    return 'Group $id with members $members';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'members': members.map((String s) => {
        'title': s
      })
    };
  }
}

class Record {
  final String modelId;
  final String modelTitle;
  Map<String, dynamic> properties;
  DateTime checkoutTime;
  String id;

  Record({
    @required this.modelId,
    @required this.modelTitle,
    @required this.properties,
    this.checkoutTime,
    this.id
  });

  Record.fromMap(Map map)
    : modelId = map['modelId'],
      modelTitle = map['modelTitle'],
      id = map['id'] {
    try {
      properties = Map.from(map['properties'].cast<String, dynamic>());
      checkoutTime = DateTime.fromMillisecondsSinceEpoch(map['checkoutTime'] * 1000);
    } catch (e) {
      throw Exception('There was an error creating your Record from a map;'
        + ' provided map is likely malformed. Check that it matches the Record'
        + ' spec. The error was: $e');
    }
  }

  Record.fromRecord(Record r)
    : modelId = r.modelId,
      modelTitle = r.modelTitle,
      properties = r.properties,
      checkoutTime = r.checkoutTime,
      id = r.id;

  @override
  String toString() {
    return 'Record { id: $id, modelId: $modelId, modelTitle: $modelTitle, properties: $properties, checkout: $checkoutTime} ';
  }

  /// Converts this record to a map representation, with key-value pairs
  /// representing fields. Note that checkoutTime's type, DateTime, is preserved
  /// when put into the map.
  Map<String, dynamic> toMap() {
    return {
      'modelId': modelId,
      'modelTitle': modelTitle,
      'id': id,
      'checkoutTime': checkoutTime,
      'properties': properties,
    };
  }
}

class CheckedOutRecord {
  Record record;
  Model model;
  String id;

  CheckedOutRecord({
    @required this.record,
    @required this.model,
    this.id
  });

  CheckedOutRecord.fromMap(Map map) {
    try {
      record = Record.fromMap(map['record']);
      model = Model.fromMap(map['model']);
      id = map['id'];
    } catch (e) {
      throw Exception('There was an error creating your CheckedOutRecord from a map;'
        + ' provided map is likely malformed. The error was: $e');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'record': record.toMap(),
      'model': model.toMap(),
      'id': id
    };
  }
}
