
import 'dart:async';
import 'dart:io';

import 'package:recycling_checkin/classes.dart' as Classes;
import 'package:recycling_checkin/utils.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final String localDbDataModelsName = 'dataCategories';
final String localDbDataRecordsName = 'dataRecords';
final String localDbDataGroupsName = 'dataGroups';
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

/// Gets models from Cloud Firestore, and use to update local
/// database's cache of models.
Future<List<Classes.Model>> getModels() async {
  return db.collection(modelsCollectionName).getDocuments().then((QuerySnapshot snaps) {
    /// Handle offline persistence of queried models, to give us more
    /// control of error messages, instead of letting Firebase do it.
    if (snaps.metadata.isFromCache) {
      throw new Exception('No internet connection!');
    }
    List<Classes.Model> models = snaps.documents.map((DocumentSnapshot snap) {
      Classes.Model toReturn = Classes.Model.fromMap(snap.data);

      /// Finish the Model with snapshot info not present in snap.data
      toReturn.id = snap.documentID;

      return toReturn;
    }).toList().cast<Classes.Model>();

    return Future.wait([
      updateCachedModels(models),
      Future.value(models)
    ]);
  }).then((List<dynamic> res) {
    /// Pass models through to future output.
    return res[1];
  });
}

Future<List<Classes.Group>> getGroups() async {
  return db.collection(groupsCollectionName).getDocuments().then((QuerySnapshot snaps) {
    // Handle offline persistence of queried groups, to give us more
    // control of error messages, instead of letting Firebase do it.
    if (snaps.metadata.isFromCache) {
      throw new Exception('No internet connection!');
    }
    List<Classes.Group> groups = snaps.documents.map((DocumentSnapshot snap) {
      Classes.Group toReturn = Classes.Group.fromMap(snap.data);

      /// Finish the Group with snapshot info not present in snap.data
      toReturn.id = snap.documentID;

      return toReturn;
    }).toList().cast<Classes.Group>();

    return Future.wait([
      updateCachedGroups(groups),
      Future.value(groups)
    ]);
  }).then((List<dynamic> res) {
    /// Pass groups through to future output.
    return res[1];
  });
}

Future<Classes.Group> getGroup(String groupId) async {
  return db.collection(groupsCollectionName).document(groupId).get().then((DocumentSnapshot doc) {
    // Handle offline persistence to give us more
    // control of error messages, instead of letting Firebase do it.
    if (doc.metadata.isFromCache) {
      throw new Exception('No internet connection!');
    }
    Classes.Group toReturn = Classes.Group.fromMap(doc.data);

    // Finish the Group with snapshot info not present in snap.data
    toReturn.id = doc.documentID;

    return toReturn;
  });
}

/// Gets cached models from local Sembast database. These are the models
/// retrieved from the last successful retrieval of models from Firestore.
Future<List<Classes.Model>> getCachedModels() async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  Finder finder = Finder(
      filter: Filter.isNull('thisFieldShouldNotExist')
  );
  StoreRef store = stringMapStoreFactory.store(localDbDataModelsName);
  return store.find(localDb, finder: finder).then((List<RecordSnapshot> snapshots) {
    return snapshots.map((RecordSnapshot snap) =>
        Classes.Model.fromMap(snap.value)
    ).toList();
  });
}

/// Gets cached groups from local Sembast database. These are the groups
/// retrieved from the last successful retrieval of groups from Firestore.
Future<List<Classes.Group>> getCachedGroups() async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  Finder finder = Finder(
    filter: Filter.isNull('thisFieldShouldNotExist')
  );
  StoreRef store = stringMapStoreFactory.store(localDbDataGroupsName);
  return store.find(localDb, finder: finder).then((List<RecordSnapshot> snapshots) {
    return snapshots.map((RecordSnapshot snap) =>
      Classes.Group.fromMap(snap.value)
    ).toList();
  });
}

/// Replaces locally stored data models with [models]. Models
/// already stored locally will be deleted and replaced completed with
/// [models].
Future<void> updateCachedModels(List<Classes.Model> models) async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(localDbDataModelsName);

  /// Transform [models] to a format compatible with Sembast.
  List<Map<String, dynamic>> modelsToAdd = models
    .map((Classes.Model model) {
      Map<String, dynamic> toReturn = model.toMap();
      // turn enums into strings
      toReturn['fields'].forEach((Map modelFields) {
        modelFields['type'] = modelFieldDataTypeToString(modelFields['type']);
      });
      return toReturn;
    }).toList();

  return store.delete(localDb).then((int numDeleted) {
    return store.addAll(localDb, modelsToAdd);
  });
}

/// Replaces locally stored data groups with [groups]. Groups
/// already stored locally will be deleted and replaced completed with
/// [groups].
Future<void> updateCachedGroups(List<Classes.Group> groups) async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(localDbDataGroupsName);

  /// Transform [groups] to a format compatible with Sembast.
  List<Map<String, dynamic>> groupsToAdd = groups
    .map((Classes.Group group) => group.toMap())
    .toList();

  return store.delete(localDb).then((int numDeleted) {
    return store.addAll(localDb, groupsToAdd);
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
/// Sets the check-in time of the record to the current time. Returns true
/// if [record] is successfully checked in, and false if [record] is being
/// queued due to offline write.
Future<bool> checkin(Classes.CheckedOutRecord record) async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(localDbDataRecordsName);

  Map toAdd = record.record.toMap();
  /// Make toAdd compatible with Firebase format
  toAdd.remove('id');
  toAdd['checkinTime'] = DateTime.now();

  // delete from local cache
  await store.record(record.id).delete(localDb);

  return Future.any([
    db.collection(recordsCollectionName).add(toAdd)
      .then((onValue) => true),
    // TODO: Firebase writes will not resolve if offline until network
    // connection is restored. To handle this, assume offline
    // creation upon a timeout of 5 seconds.
    Future.delayed(Duration(seconds: 5)).then((onValue) => false),
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

  // replace enums with strings
  toAdd['model']['fields'].forEach((Map modelFields) {
    modelFields['type'] = modelFieldDataTypeToString(modelFields['type']);
  });

  var key = await store.add(localDb, toAdd);
  return key;
}
