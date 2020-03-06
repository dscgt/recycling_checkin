
import 'dart:async';
import 'dart:io';

import 'package:recycling_checkin/classes.dart' as Classes;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recycling_checkin/utils.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final String localDbDataCategoriesName = 'dataCategories';
final String localDbDataRecordsName = 'dataRecords';
final Firestore db = Firestore.instance;
final String recordsCollectionName = 'test_records';
final String dataCategoriesCollectionName = 'test_models';

/// Gets the path on local filesystem that will be used to reference local
/// storage for Sembast.
Future<String> getLocalDbPath() async {
  Directory directory = await getApplicationDocumentsDirectory();
  return join(directory.path, 'recycling_checkout.db');
}

/// Gets data categories from Cloud Firestore, and use to update local
/// database's cache of data categories.
Future<List<Classes.DataCategory>> getCategories() async {
  return db.collection('test_models').getDocuments().then((QuerySnapshot snaps) {
    List<Classes.DataCategory> categories = snaps.documents.map((DocumentSnapshot snap) {
      return Classes.DataCategory(
        title: snap.data['title'],
        id: snap.documentID,
        properties: snap.data['fields'].map((dynamic field) {
          return Classes.DataProperty(
            title: field['title'],
            type: field['type'] == 'string'
              ? Classes.DataType.string
              : Classes.DataType.number
          );
        }).toList().cast<Classes.DataProperty>()
      );
    }).toList().cast<Classes.DataCategory>();

    return Future.wait([
      updateCachedCategories(categories),
      Future.value(categories)
    ]);
  }).then((List<dynamic> res) {
    /// Pass categories through to future output.
    return res[1];
  });
}

/// Gets cached categories from local Sembast database. These are the categories
/// retrieved from the last successful GET of categories from Firestore.
Future<List<Classes.DataCategory>> getCachedCategories() async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  Finder finder = Finder(
    filter: Filter.isNull('thisFieldShouldNotExist')
  );
  StoreRef store = stringMapStoreFactory.store(localDbDataCategoriesName);
  return store.find(localDb, finder: finder).then((List<RecordSnapshot> snapshots) {
    return snapshots.map((RecordSnapshot snap) {
      return Classes.DataCategory(
        id: snap['id'],
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

/// Replaces locally stored data categories with [categories]. Categories
/// already stored locally will be deleted and replaced completed with
/// [categories].
Future<void> updateCachedCategories(List<Classes.DataCategory> categories) async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(localDbDataCategoriesName);

  /// Transform [categories] to a format compatible with Sembast.
  List<Map<String, dynamic>> categoriesToAdd = categories.map((Classes.DataCategory category) {
    return {
      'title': category.title,
      'id': category.id,
      'properties': category.properties.map((Classes.DataProperty prop) {
        return {
          'title': prop.title,
          'type': '${prop.type}'
        };
      }).toList()
    };
  }).toList();

  return store.delete(localDb).then((int numDeleted) {
    return store.addAll(localDb, categoriesToAdd);
  });
}

/// Gets records of items currently checked out.
Future<List<Classes.Record>> getRecords() async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  Filter filter = Filter.isNull('checkinTime');
  StoreRef store = stringMapStoreFactory.store(localDbDataRecordsName);
  return store.find(localDb, finder: Finder(
    filter: filter
  )).then((List<RecordSnapshot> snapshots) {
    return snapshots.map((RecordSnapshot snap) {
      // convert snapshot to Record
      Map<String, dynamic> otherProps = Map.fromEntries(snap.value.entries);
      otherProps.remove('categoryId');
      otherProps.remove('checkoutTime');
      Classes.Record toReturn = Classes.Record(
        categoryId: snap['categoryId'],
        properties: otherProps,
        id: snap.key
      );
      if (snap['checkoutTime'] != null) {
        toReturn.checkoutTime = DateTime.fromMillisecondsSinceEpoch(snap['checkoutTime'] * 1000);
      }
      return toReturn;
    }).toList();
  });
}

/// Checks in a [record]. Deletes it from local cache and submits to Firebase.
/// Sets the check-in time of the record to the current time.
Future<dynamic> checkin(Classes.Record record) async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(localDbDataRecordsName);

  return Future.wait([
    // delete from local cache
    store.record(record.id).delete(localDb),
    // submit to Firebase
    db.collection(recordsCollectionName).add({
      'categoryId': record.categoryId,
      'checkoutTime': record.checkoutTime,
      'checkinTime': DateTime.now(),
      'properties': record.properties
    })
  ]);
}

/// Saves the record [record] to local storage. For checking out.
Future<dynamic> checkout(Classes.Record record) async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(localDbDataRecordsName);

  Map<String, dynamic> toAdd = {
    'categoryId': record.categoryId,
    'checkoutTime': record.checkoutTime,
  };
  toAdd.addAll(record.properties);

  // use current time as checkout time if not specified by record
  if (toAdd['checkoutTime'] == null) {
    toAdd['checkoutTime'] = (DateTime.now().millisecondsSinceEpoch / 1000).round();
  }

  var key = await store.add(localDb, toAdd);
  return key;
}
