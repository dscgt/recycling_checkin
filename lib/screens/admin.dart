import 'package:flutter/material.dart';
import 'package:recycling_checkin/api.dart';
import 'package:recycling_checkin/classes.dart';

enum ConfirmAction { CANCEL, CONFIRM }

class Admin extends StatefulWidget {

  @override
  AdminState createState() {
    return AdminState();
  }
}

class AdminState extends State<Admin> {
  final _optionSetFormKey = GlobalKey<FormState>();
  Future<List<DataCategory>> _optionSetListFuture = getCategories();
  bool showOptionSetForm = false;
  final _optionSetNameController = TextEditingController();
  List<DataProperty> optionSetProperties = [];

  initState() {
    /// Initialize the form with an empty option set to give the user a
    /// starting point.
    optionSetProperties = [
      DataProperty(
        title: '',
        type: DataType.string
      )
    ];

    super.initState();
  }

  _handleAddOptionSet() async {
    if (!_optionSetFormKey.currentState.validate()) {
      return;
    }

    DataCategory toAdd = DataCategory(
      title: _optionSetNameController.text,
      properties: optionSetProperties
    );

    await addDataCategory(toAdd);

    /// After adding an option set, hide the form and refresh the future that
    /// retrieves option sets.
    setState(() {
      showOptionSetForm = false;
      _optionSetListFuture = getCategories();
    });
  }

  _handleAddOptionSetProperty() {
    setState(() {
      optionSetProperties.add(DataProperty(
        title: '',
        type: DataType.string
      ));
    });
  }

  _handleShowOptionSetForm() {
    setState(() {
      showOptionSetForm = true;
    });
  }

  _handleHideOptionSetForm() {
    setState(() {
      showOptionSetForm = false;
    });
  }

  _handleDeleteOptionSet(String id) async {
    await deleteCategory(id);

    /// Refresh option set future after deletion of an option set.
    setState(() {
      _optionSetListFuture = getCategories();
    });
  }

  dispose() {
    _optionSetNameController.dispose();
    super.dispose();
  }

  Widget _buildOptionSetList(List<DataCategory> categories) {
    List<Widget> categoryElements = categories.map((DataCategory dc) {
      List<Widget> propertyViews = [
        Text('${dc.title} checkouts.\nA crewmember must enter:'),
      ];
      propertyViews.addAll(dc.properties.map((DataProperty dp) {
        if (dp.type == DataType.number) {
           return Text('${dp.title} (only numbers allowed)');
        }
        return Text('${dp.title}');
      }).toList());
      propertyViews.addAll([
        IconButton(
          icon: Icon(Icons.delete),
          onPressed: () {
            showDialog<ConfirmAction>(
              context: context,
              barrierDismissible: true,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Are you sure you want to delete this?'),
                  actions: <Widget>[
                    FlatButton(
                      onPressed: () {
                        Navigator.of(context).pop(ConfirmAction.CANCEL);
                      },
                      child: const Text('CANCEL'),
                    ),
                    FlatButton(
                      onPressed: () {
                        Navigator.of(context).pop(ConfirmAction.CONFIRM);
                        _handleDeleteOptionSet(dc.id);
                      },
                      child: const Text('CONFIRM'),
                    ),
                  ],
                );
              }
            );
          },
        ),

      ]);

      return Card(
        child: Column(
          children: propertyViews
        ),
      );
    }).toList();

    return ListView(
      shrinkWrap: true,
      children: categoryElements
    );
  }

  Widget _buildOptionSetForm() {
    List<Widget> formElements = [
      /// First, create the field where user can define an option set's name.
      TextFormField(
        controller: _optionSetNameController,
        validator: (value) {
          if (value.isEmpty) {
            return 'This field must be filled out.';
          }
          return null;
        },
        decoration: const InputDecoration(
          hintText: 'A broad check-out category (ex. Vehicle, Fuel Card...)',
          labelText: 'Option set name',
        ),
      ),
    ];
    /// Then, create fields for all properties of the option set. User will be
    /// able to modify a property's name and type (between DataType.string and
    /// DataType.integer) and delete properties.
    for (int i = 0; i < optionSetProperties.length; i++) {
      DataProperty thisProp = optionSetProperties[i];
      formElements.add(Row(
        children: <Widget>[
          Expanded(
            child: TextFormField(
              validator: (value) {
                if (value.isEmpty) {
                  return 'This field must be filled out.';
                }
                return null;
              },
              decoration: const InputDecoration(
                hintText: 'A required detail (ex. name)',
                labelText: 'Option set detail',
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle_outline),
            onPressed: () {
              setState(() {
                optionSetProperties.removeAt(i);
              });
            },
          ),
          Checkbox(
            onChanged: (bool checked) {
              setState(() {
                optionSetProperties[i].type = checked
                  ? DataType.number
                  : DataType.string;
              });
            },
            value: thisProp.type == DataType.number
          ),
          Text('Only allow numbers')
        ],
      ));
    }
    /// Finally, create options for adding more properties to this new option
    /// set, and submission.
    formElements.addAll([
      RaisedButton(
        onPressed: () => _handleAddOptionSetProperty(),
        child: Text('Add property?')
      ),
      Text(
        'Note: you won\'t need to add properties for check-in and check-out time. These are handled automatically.',
      ),
      Row(
        children: <Widget>[
          RaisedButton(
            onPressed: () => _handleAddOptionSet(),
            child: Text('Submit'),
          ),
          RaisedButton(
            onPressed: () => _handleHideOptionSetForm(),
            child: Text('Cancel'),
          )
        ],
      )
    ]);

    return Form(
      key: _optionSetFormKey,
      child: Column(
        children: formElements
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Text(
            'Here you can control what options crewmembers have when they check in and out.'
          ),
          Text(
            'Crewmember options:'
          ),
          FutureBuilder(
            future: _optionSetListFuture,
            builder: (BuildContext context, AsyncSnapshot<List<DataCategory>> snapshot) {
              if (snapshot.hasData) {
                return _buildOptionSetList(snapshot.data);
              } else if (snapshot.hasError) {
                return Text('Error happened...yikes. Try again?');
              } else {
                return Text('Loading...');
              }
            }
          ),
          showOptionSetForm
            ? null
            : RaisedButton(
              onPressed: () => _handleShowOptionSetForm(),
              child: Text('Add option set?')
            ),
          showOptionSetForm ? _buildOptionSetForm() : null,
        ].where((Object o) => o != null).toList(),
      )
    );
  }
}
