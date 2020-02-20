
import 'dart:async';
import 'dart:io';

import 'package:password/password.dart';
import 'package:recycling_checkin/classes.dart' as Classes;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recycling_checkin/utils.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:shared_preferences/shared_preferences.dart';

final String dbName = 'recycling_checkout.db';
final String dataCategoriesName = 'dataCategories';
final String dataRecordsName = 'dataRecords';

/// Attempts [password] with the stored admin password, returning a Future with
/// the boolean result of whether [password] is correct or not.
Future<bool> checkPassword(String password) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String storedPassword = prefs.getString('pwd') ?? 'String';
  return Password.verify(password, storedPassword);
}

/// Updates the stored admin password with a hash of [newPassword].
Future<void> updateAdminPassword(String newPassword) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String thisPassword = Password.hash(newPassword, new PBKDF2());
  return prefs.setString('pwd', thisPassword);
}

/// Gets the path on local filesystem that will be used to reference local
/// storage for Sembast.
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
        id: snap.key,
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

/// Gets all checkout records ever submitted, unless [onlyNotCheckedIn] is
/// specified to true; in this case, gets only the checkout records with a null
/// or nonexistant checkinTime field, indicating some item that is checked out and
/// has not been checked back in.
Future<List<Classes.Record>> getRecords([bool onlyNotCheckedIn = false]) async {
  String dbPath = await getDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database db = await dbFactory.openDatabase(dbPath);
  Filter filter;
  if (onlyNotCheckedIn) {
    filter = Filter.isNull('checkinTime');
  } else {
    filter = Filter.isNull('thisFieldShouldNotExist');
  }
  StoreRef store = stringMapStoreFactory.store(dataRecordsName);
  return store.find(db, finder: Finder(
    filter: filter
  )).then((List<RecordSnapshot> snapshots) {
    return snapshots.map((RecordSnapshot snap) {
      // convert snapshot to Record
      Map<String, dynamic> otherProps = Map.fromEntries(snap.value.entries);
      otherProps.remove('category');
      otherProps.remove('checkinTime');
      otherProps.remove('checkoutTime');
      Classes.Record toReturn = Classes.Record(
        category: snap['category'],
        properties: otherProps,
        id: snap.key
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

/// Updates the data category of id [id] by ovewriting it with details from
/// [category].
Future<dynamic> updateDataCategory(String id, Classes.DataCategory category) async {
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

  return store.record(id).put(db, {
    'title': category.title,
    'properties': properties
  }, merge: true);
}

/// Checks in a record of ID [recordId]. Sets the check-in time of a record to
/// the current time.
Future<dynamic> checkin(String recordId) async {
  String dbPath = await getDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database db = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(dataRecordsName);

  return store.record(recordId).update(db, {
    'checkinTime': (DateTime.now().millisecondsSinceEpoch / 1000).round()
  });
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

/// Deletes the category with id [id].
Future<void> deleteCategory(String id) async {
  String dbPath = await getDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database db = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(dataCategoriesName);

  return store.record(id).delete(db);
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
