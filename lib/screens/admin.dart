import 'package:flutter/material.dart';
import 'package:recycling_checkin/api.dart';
import 'package:recycling_checkin/classes.dart';

class Admin extends StatefulWidget {

  @override
  AdminState createState() {
    return AdminState();
  }
}

class AdminState extends State<Admin> {
  String dbPath;

  _handleAddCategory() async {
    // add dummy categories for now
    DataCategory dummyCategory1 = DataCategory(
      title: 'Vehicle',
      properties: [
        DataProperty(
          title: 'Name',
          type: DataType.string
        ),
        DataProperty(
          title: 'Vehicle #',
          type: DataType.string
        )
      ]
    );
    DataCategory dummyCategory2 = DataCategory(
      title: 'Fuel Card',
      properties: [
        DataProperty(
          title: 'Name',
          type: DataType.string
        ),
        DataProperty(
          title: 'Vehicle # (for fuel card)',
          type: DataType.string
        )
      ]
    );

    await addDataCategory(dummyCategory1);
    await addDataCategory(dummyCategory2);
    print('test done');
  }

  _handleViewCategories() async {
    List<DataCategory> categories = await getCategories();
    print(categories);
  }

  _handleDeleteCategories() async {
    await deleteCategories();
    print('test done');
  }

  _handleViewRecords() async {
    List<Record> records = await getRecords();
    print(records);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        RaisedButton(
          onPressed: () => _handleAddCategory(),
          child: Text('Add categories'),
        ),
        RaisedButton(
          onPressed: () => _handleViewCategories(),
          child: Text('View categories'),
        ),
        RaisedButton(
          onPressed: () => _handleDeleteCategories(),
          child: Text('Delete all categories'),
        ),
        RaisedButton(
          onPressed: () => _handleViewRecords(),
          child: Text('View records'),
        ),
      ],
    );
  }
}
