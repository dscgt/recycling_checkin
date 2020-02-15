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
  Future<List<DataCategory>> _optionSetListFuture = getCategories();
  bool showOptionSetForm = false;

  initState() {
    super.initState();
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

  handleOptionSetAdded() {
    setState(() {
      showOptionSetForm = false;
      _optionSetListFuture = getCategories();
    });
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

    return Column(
      children: categoryElements
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
            ? RaisedButton(
              onPressed: () => _handleHideOptionSetForm(),
              child: Text('Cancel'))
            : RaisedButton(
              onPressed: () => _handleShowOptionSetForm(),
              child: Text('Add option set?')),
          showOptionSetForm ? OptionSet(
            addOptionSetCallback: handleOptionSetAdded
          ) : null,
        ].where((Object o) => o != null).toList(),
      )
    );
  }
}

class OptionSet extends StatefulWidget {
  final Function addOptionSetCallback;

  const OptionSet({Key key, this.addOptionSetCallback}): super(key: key);

  @override
  OptionSetState createState() {
    return OptionSetState();
  }
}

class PropertyEntry {
  final TextEditingController controller;
  DataType type;

  PropertyEntry({
    @required this.controller,
    @required this.type,
  });
}

class OptionSetState extends State<OptionSet> {
  List<PropertyEntry> optionSetPropertyControllers = [];
  final _optionSetFormKey = GlobalKey<FormState>();
  final _optionSetNameController = TextEditingController();


  initState() {
    /// Initialize the form with an empty option set to give the user a
    /// starting point.
    optionSetPropertyControllers = [
      PropertyEntry(
        controller: TextEditingController(),
        type: DataType.string
      )
    ];
    super.initState();
  }

  dispose() {
    _optionSetNameController.dispose();
    optionSetPropertyControllers.forEach((PropertyEntry pe) {
      pe.controller.dispose();
    });
    super.dispose();
  }

  _handleAddOptionSet() async {
    if (!_optionSetFormKey.currentState.validate()) {
      return;
    }
    DataCategory toAdd = DataCategory(
      title: _optionSetNameController.text,
      properties: optionSetPropertyControllers.map((PropertyEntry pe) {
        return DataProperty(
          title: pe.controller.text,
          type: pe.type
        );
      }).toList()
    );
    await addDataCategory(toAdd);

    widget.addOptionSetCallback();
  }

  _handleAddOptionSetProperty() {
    setState(() {
      optionSetPropertyControllers.add(PropertyEntry(
        controller: TextEditingController(),
        type: DataType.string
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
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
    for (int i = 0; i < optionSetPropertyControllers.length; i++) {
      PropertyEntry thisProp = optionSetPropertyControllers[i];
      formElements.add(Row(
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: thisProp.controller,
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
                optionSetPropertyControllers.removeAt(i);
              });
            },
          ),
          Checkbox(
              onChanged: (bool checked) {
                setState(() {
                  optionSetPropertyControllers[i].type = checked
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
}
