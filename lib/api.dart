
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
final String recordsCollectionName = 'records';
final String modelsCollectionName = 'models';
final String groupsCollectionName = 'groups';
final Firestore db = Firestore.instance;

/// Gets the path on local filesystem that will be used to reference local
/// storage for Sembast.
Future<String> getLocalDbPath() async {
  Directory directory = await getApplicationDocumentsDirectory();
  return join(directory.path, 'recycling_checkout.db');
}

/// Gets data categories from Cloud Firestore, and use to update local
/// database's cache of data categories.
Future<List<Classes.Model>> getCategories() async {
  return db.collection(modelsCollectionName).getDocuments().then((QuerySnapshot snaps) {
    /// Handle offline persistence of queried categories, to give us more
    /// control of error messages, instead of letting Firebase do it.
    if (snaps.metadata.isFromCache) {
      throw new Exception('No internet connection!');
    }
    List<Classes.Model> categories = snaps.documents.map((DocumentSnapshot snap) {
      return Classes.Model(
        title: snap.data['title'],
        id: snap.documentID,
        properties: snap.data['fields'].map((dynamic field) {
          return Classes.ModelField(
            title: field['title'],
            optional: field['optional'] ?? false,
            delay: field['delay'] ?? false,
            type: field['type'] == 'string'
              ? Classes.ModelFieldDataType.string
              : Classes.ModelFieldDataType.number
          );
        }).toList().cast<Classes.ModelField>()
      );
    }).toList().cast<Classes.Model>();

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
Future<List<Classes.Model>> getCachedCategories() async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  Finder finder = Finder(
    filter: Filter.isNull('thisFieldShouldNotExist')
  );
  StoreRef store = stringMapStoreFactory.store(localDbDataCategoriesName);
  return store.find(localDb, finder: finder).then((List<RecordSnapshot> snapshots) {
    return snapshots.map((RecordSnapshot snap) {
      return Classes.Model(
        id: snap['id'],
        title: snap['title'],
        properties: snap['properties'].map((record) {
          return Classes.ModelField(
            title: record['title'],
            optional: record['optional'] ?? false,
            delay: record['delay'] ?? false,
            type: stringToModelFieldDataType(record['type'])
          );
        }).cast<Classes.ModelField>().toList()
      );
    }).toList();
  });
}

/// Replaces locally stored data categories with [categories]. Categories
/// already stored locally will be deleted and replaced completed with
/// [categories].
Future<void> updateCachedCategories(List<Classes.Model> categories) async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(localDbDataCategoriesName);

  /// Transform [categories] to a format compatible with Sembast.
  List<Map<String, dynamic>> categoriesToAdd = categories.map((Classes.Model category) {
    return {
      'title': category.title,
      'id': category.id,
      'properties': category.properties.map((Classes.ModelField prop) {
        return {
          'title': prop.title,
          'type': modelFieldDataTypeToString(prop.type)
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
      otherProps.remove('modelId');
      otherProps.remove('modelTitle');
      otherProps.remove('checkoutTime');
      Classes.Record toReturn = Classes.Record(
        modelId: snap['modelId'],
        modelTitle: snap['modelTitle'],
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
    Future.any([
      /// TODO: Firebase writes when offline never resolve, even though they
      /// do (usually) sync properly when online. This results in a future
      /// that never resolves, thus, this function assumes a successful
      /// creation upon a timeout of 5 seconds. This is a dangerous assumption
      /// to make; handle this better.
      Future.delayed(Duration(seconds: 5)).then((onValue) => null),
      db.collection(recordsCollectionName).add({
        'modelId': record.modelId,
        'modelTitle': record.modelTitle,
        'checkoutTime': record.checkoutTime,
        'checkinTime': DateTime.now(),
        'properties': record.properties
      })
    ])
  ]);
}

/// Saves the record [record] to local storage. For checking out.
Future<dynamic> checkout(Classes.Record record) async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(localDbDataRecordsName);

  Map<String, dynamic> toAdd = {
    'modelId': record.modelId,
    'modelTitle': record.modelTitle,
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
