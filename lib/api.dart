
import 'dart:io';

import 'package:recycling_checkin/classes.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recycling_checkin/utils.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

Future<List<DataCategory>> getCategories() async {
  Directory directory = await getApplicationDocumentsDirectory();
  String dbPath = join(directory.path, 'recycling_checkout.db');
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database db = await dbFactory.openDatabase(dbPath);
  Finder finder = Finder(
    filter: Filter.isNull('thisFieldShouldNotExist')
  );
  StoreRef store = stringMapStoreFactory.store('dataCategories');
  return store.find(db, finder: finder).then((List<RecordSnapshot> snapshots) {
    return snapshots.map((RecordSnapshot snap) {
      return DataCategory(
        title: snap['title'],
        properties: snap['properties'].map((record) {
          return DataProperty(
            title: record['title'],
            type: stringToDataType(record['type'])
          );
        }).cast<DataProperty>().toList()
      );
    }).toList();
  });
}

Future<String> addDataCategory(DataCategory category) async {
  Directory directory = await getApplicationDocumentsDirectory();
  String dbPath = join(directory.path, 'recycling_checkout.db');
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database db = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store('dataCategories');

  List<Map<String, String>> properties = category
    .properties
    .map((DataProperty prop) {
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

Future<void> deleteCategories() async {
  Directory directory = await getApplicationDocumentsDirectory();
  String dbPath = join(directory.path, 'recycling_checkout.db');
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database db = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store('dataCategories');

  await store.drop(db);
  return Future.value();
}
