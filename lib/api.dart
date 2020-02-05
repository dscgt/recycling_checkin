
import 'dart:io';

import 'package:recycling_checkin/classes.dart' as Classes;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recycling_checkin/utils.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

final String dbName = 'recycling_checkout.db';
final String dataCategoriesName = 'dataCategories';
final String dataRecordsName = 'dataRecords';

Future<String> getDbPath() async {
  Directory directory = await getApplicationDocumentsDirectory();
  return join(directory.path, 'recycling_checkout.db');
}

Future<List<Classes.DataCategory>> getCategories() async {
  String dbPath = await getDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database db = await dbFactory.openDatabase(dbPath);
  Finder finder = Finder(
    filter: Filter.isNull('thisFieldShouldNotExist')
  );
  StoreRef store = stringMapStoreFactory.store(dataCategoriesName);
  return store.find(db, finder: finder).then((List<RecordSnapshot> snapshots) {
    return snapshots.map((RecordSnapshot snap) {
      return Classes.DataCategory(
        title: snap['title'],
        properties: snap['properties'].map((record) {
          return Classes.DataProperty(
            title: record['title'],
            type: stringToDataType(record['type'])
          );
        }).cast<Classes.DataProperty>().toList()
      );
    }).toList();
  });
}

Future<List<Classes.Record>> getRecords() async {
  String dbPath = await getDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database db = await dbFactory.openDatabase(dbPath);
  Finder finder = Finder(
    filter: Filter.isNull('thisFieldShouldNotExist')
  );
  StoreRef store = stringMapStoreFactory.store(dataRecordsName);
  return store.find(db, finder: finder).then((List<RecordSnapshot> snapshots) {
    return snapshots.map((RecordSnapshot snap) {
      // convert snapshot to Record
      Map<String, dynamic> otherProps = Map.fromEntries(snap.value.entries);
      otherProps.remove('type');
      otherProps.remove('checkinTime');
      otherProps.remove('checkoutTime');
      Classes.Record toReturn = Classes.Record(
        category: snap['category'],
        properties: otherProps
      );
      if (snap['checkoutTime'] != null) {
        toReturn.checkoutTime = DateTime.fromMillisecondsSinceEpoch(snap['checkoutTime'] * 1000);
      }
      if (snap['checkinTime'] != null) {
        toReturn.checkinTime = DateTime.fromMillisecondsSinceEpoch(snap['checkinTime'] * 1000);
      }
      return toReturn;
    }).toList();
  });
}

Future<String> addDataCategory(Classes.DataCategory category) async {
  String dbPath = await getDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database db = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(dataCategoriesName);

  List<Map<String, String>> properties = category
    .properties
    .map((Classes.DataProperty prop) {
    return {
      'title': prop.title,
      'type': '${prop.type}'
    };
  }).toList();

  var key = await store.add(db, {
    'title': category.title,
    'properties': properties
  });

  return key;
}

/// Saves the record [record] to local storage.
Future<dynamic> checkout(Classes.Record record) async {
  String dbPath = await getDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database db = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(dataRecordsName);

  Map<String, dynamic> toAdd = {
    'category': record.category,
    'checkinTime': record.checkinTime,
    'checkinTime': record.checkoutTime,
  };
  toAdd.addAll(record.properties);

  // use current time as checkout time if not specified by record
  if (toAdd['checkoutTime'] == null) {
    toAdd['checkoutTime'] = (DateTime.now().millisecondsSinceEpoch / 1000).round();
  }

  var key = await store.add(db, toAdd);
  return key;
}

Future<void> deleteCategories() async {
  String dbPath = await getDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database db = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(dataCategoriesName);

  await store.drop(db);
  return Future.value();
}

Future<void> deleteRecords() async {
  String dbPath = await getDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database db = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(dataRecordsName);

  await store.drop(db);
  return Future.value();
}
