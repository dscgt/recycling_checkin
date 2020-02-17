import 'package:flutter/material.dart';
import 'package:recycling_checkin/api.dart';
import 'package:recycling_checkin/classes.dart';
import 'package:provider/provider.dart';

enum ConfirmAction { CANCEL, CONFIRM }

/// Entrypoint for the Admin tree of widgets.
class Admin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AdminData(),
      child: AdminWrapper()
    );
  }
}

class AdminData extends ChangeNotifier {
  Future<List<DataCategory>> _optionSetsFuture = getCategories();

  Future<List<DataCategory>> get optionSetsFuture => _optionSetsFuture;

  void updateFuture(Future<List<DataCategory>> fut) {
    _optionSetsFuture = fut;
    notifyListeners();
  }
}

class AdminWrapper extends StatefulWidget {

  @override
  AdminWrapperState createState() {
    return AdminWrapperState();
  }
}

class AdminWrapperState extends State<AdminWrapper> {
  bool showOptionSetForm = false;

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

  handleOptionSetAdded() {
    setState(() {
      showOptionSetForm = false;
    });
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
          OptionSetList(),
          showOptionSetForm
            ? RaisedButton(
              onPressed: () => _handleHideOptionSetForm(),
              child: Text('Cancel'))
            : RaisedButton(
              onPressed: () => _handleShowOptionSetForm(),
              child: Text('Add option set?')),
          showOptionSetForm ? AddOptionSet(
            addOptionSetCallback: handleOptionSetAdded
          ) : null,
        ].where((Object o) => o != null).toList(),
      )
    );
  }
}

class OptionSetList extends StatefulWidget {
  const OptionSetList({Key key}): super(key: key);

  @override
  OptionSetListState createState() {
    return OptionSetListState();
  }
}

class OptionSetListState extends State<OptionSetList> {

  _handleDeleteOptionSet(String id) async {
    await deleteCategory(id);
    Provider.of<AdminData>(context, listen:false).updateFuture(getCategories());
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

  Widget build(BuildContext context) {
    return Consumer<AdminData>(
      builder: (context, adminData, child) {
        return FutureBuilder(
          future: adminData.optionSetsFuture,
          builder: (BuildContext context, AsyncSnapshot<List<DataCategory>> snapshot) {
            if (snapshot.hasData) {
              return _buildOptionSetList(snapshot.data);
            } else if (snapshot.hasError) {
              return Text('Error happened...yikes. Try again?');
            } else {
              return Text('Loading...');
            }
          }
        );
      }
    );
  }
}

class AddOptionSet extends StatefulWidget {
  final Function addOptionSetCallback;

  const AddOptionSet({Key key, this.addOptionSetCallback}): super(key: key);

  @override
  AddOptionSetState createState() {
    return AddOptionSetState();
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

class AddOptionSetState extends State<AddOptionSet> {
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

    Provider.of<AdminData>(context, listen:false).updateFuture(getCategories());
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
