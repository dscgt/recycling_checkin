
import 'dart:async';
import 'dart:io';

import 'package:recycling_checkin/classes.dart' as Classes;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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
      Classes.Model toReturn = Classes.Model.fromMap(snap.data);

      /// Finish the Model with snapshot info not present in snap.data
      toReturn.id = snap.documentID;

      return toReturn;
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
    return snapshots.map((RecordSnapshot snap) =>
      Classes.Model.fromMap(snap.value)
    ).toList();
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
  List<Map<String, dynamic>> categoriesToAdd = categories
    .map((Classes.Model category) => category.toMap())
    .toList();

  return store.delete(localDb).then((int numDeleted) {
    return store.addAll(localDb, categoriesToAdd);
  });
}

/// Gets records of items currently checked out.
Future<List<Classes.CheckedOutRecord>> getRecords() async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  Filter filter = Filter.isNull('checkinTime');
  StoreRef store = stringMapStoreFactory.store(localDbDataRecordsName);
  return store.find(localDb, finder: Finder(
    filter: filter
  )).then((List<RecordSnapshot> snapshots) {
    return snapshots.map((RecordSnapshot snap) {
      Classes.CheckedOutRecord toReturn = Classes.CheckedOutRecord.fromMap(snap.value);
      toReturn.id = snap.key;
      return toReturn;
    }).toList();
  });
}

/// Checks in a [record]. Deletes it from local cache and submits to Firebase.
/// Sets the check-in time of the record to the current time.
Future<dynamic> checkin(Classes.CheckedOutRecord record) async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(localDbDataRecordsName);

  Map toAdd = record.record.toMap();
  /// Make toAdd compatible with Firebase format
  toAdd.remove('id');
  toAdd['checkinTime'] = DateTime.now();

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
      db.collection(recordsCollectionName).add(toAdd)
    ])
  ]);
}

/// Saves the record [record] to local storage. For checking out.
Future<dynamic> checkout(Classes.CheckedOutRecord record) async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(localDbDataRecordsName);

  Map<String, dynamic> toAdd = record.toMap();
  // use current time as checkout time if not specified by record
  if (toAdd['record']['checkoutTime'] == null) {
    toAdd['record']['checkoutTime'] = (DateTime.now().millisecondsSinceEpoch / 1000).round();
  }

  var key = await store.add(localDb, toAdd);
  return key;
}
