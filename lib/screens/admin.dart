import 'dart:async';

import 'package:flutter/material.dart';
import 'package:recycling_checkin/api.dart';
import 'package:recycling_checkin/classes.dart';
import 'package:provider/provider.dart';
import 'package:recycling_checkin/screens/edit_option_set.dart';

enum ConfirmAction { CANCEL, CONFIRM }
TextStyle adminTextStyle = TextStyle(
  fontSize: 18.0
);

/// Entrypoint for the Admin tree of widgets.
class Admin extends StatelessWidget {
  final StreamController<AdminAuthenticationState> adminAuthController;

  const Admin({
    Key key,
    this.adminAuthController
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AdminData(),
      child: AdminWrapper(
        adminAuthController: adminAuthController
      )
    );
  }
}

/// Stores data required by all of the admin tree. This consists of a future
/// for getting option sets, and an update function to update that future
/// for refresh.
class AdminData extends ChangeNotifier {
  Future<List<DataCategory>> _optionSetsFuture = getCategories();

  Future<List<DataCategory>> get optionSetsFuture => _optionSetsFuture;

  void updateFuture(Future<List<DataCategory>> fut) {
    _optionSetsFuture = fut;
    notifyListeners();
  }
}

/// Parent widget to OptionSetList and AddOptionSet. Handles visibility of
/// option set adding form,
class AdminWrapper extends StatefulWidget {
  final StreamController<AdminAuthenticationState> adminAuthController;

  const AdminWrapper({
    Key key,
    this.adminAuthController
  }): super(key: key);

  @override
  AdminWrapperState createState() {
    return AdminWrapperState();
  }
}
class AdminWrapperState extends State<AdminWrapper> {
  bool showOptionSetForm = false;
  bool showPasswordChangeForm = false;

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

  _handleOptionSetAdded() {
    setState(() {
      showOptionSetForm = false;
    });
  }

  _handlePasswordChange() {
    setState(() {
      showPasswordChangeForm = false;
    });
  }

  _handleLogOut() {
    widget.adminAuthController.add(AdminAuthenticationState.NO);
  }

  Widget _buildChangePasswordForm() {
    if (showPasswordChangeForm) {
      return Column(
        children: <Widget>[
          RaisedButton(
            onPressed: () {
              setState(() {
                showPasswordChangeForm = false;
              });
            },
            child: Text(
              'Cancel change password',
              style: adminTextStyle
            )
          ),
          ChangeAdminPassword(
            passwordChangeCallback: _handlePasswordChange,
          )
        ],
      );
    } else {
      return Column(
        children: <Widget>[
          RaisedButton(
            onPressed: () {
              setState(() {
                showPasswordChangeForm = true;
              });
            },
            child: Text(
              'Change password?',
              style: adminTextStyle
            )
          ),
        ],
      );
    }
  }

  Widget _buildAddOptionSetForm() {
    if (showOptionSetForm) {
      return Column(
        children: <Widget>[
          RaisedButton(
            onPressed: () => _handleHideOptionSetForm(),
            child: Text('Cancel add option set',
              style: adminTextStyle,
            )
          ),
          AddOptionSet(
            addOptionSetCallback: _handleOptionSetAdded
          )
        ],
      );
    } else {
      return Column(
        children: <Widget>[
          RaisedButton(
            onPressed: () => _handleShowOptionSetForm(),
            child: Text(
              'Add option set?',
              style: adminTextStyle
            )
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Text(
              'Here you can control what options crewmembers have when they check in and out.',
              style: adminTextStyle
            ),
            OptionSetList(),
            Container(
              padding: const EdgeInsets.only(bottom: 30),
              child: _buildAddOptionSetForm(),
            ),
            _buildChangePasswordForm(),
            RaisedButton(
              child: Text('Log out of admin page', style: adminTextStyle),
              onPressed: () => _handleLogOut(),
            ),
          ],
        )
      )
    );
  }
}

/// Widget for list of option set cards. Creates a list of OptionSetCard.
class OptionSetList extends StatefulWidget {
  const OptionSetList({Key key}): super(key: key);

  @override
  OptionSetListState createState() {
    return OptionSetListState();
  }
}
class OptionSetListState extends State<OptionSetList> {

  Widget _buildOptionSetList(List<DataCategory> categories) {
    List<Widget> categoryElements = categories.map((DataCategory dc) {
      return OptionSetCard(
        dataCategory: dc
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

// Widget for a single option set card. A list of these is created by
// OptionSetList.
class OptionSetCard extends StatefulWidget {
  final DataCategory dataCategory;

  OptionSetCard({Key key, this.dataCategory}): super(key: key);

  @override
  OptionSetCardState createState() {
    return OptionSetCardState();
  }
}
class OptionSetCardState extends State<OptionSetCard> {
  @override
  void initState() {
    super.initState();
  }

  /// Deletes this option set.
  _deleteOptionSet() async {
    await deleteCategory(widget.dataCategory.id);
    Provider.of<AdminData>(context, listen:false).updateFuture(getCategories());
  }

  /// Handles user tap on option set deletion.
  void _handleDeleteOptionSet(BuildContext context) {
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
                _deleteOptionSet();
              },
              child: const Text('CONFIRM'),
            ),
          ],
        );
      }
    );
  }

  /// Handles user tap on option set edit. Directs user to page for editing
  /// option sets.
  void _handleEdit(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditOptionSet(
          dataCategory: widget.dataCategory
      )),
    );
    Provider.of<AdminData>(context, listen:false).updateFuture(getCategories());
  }

  Widget build(BuildContext context) {
    DataCategory dc = widget.dataCategory;
    return Card(
      child: Container(
        padding: const EdgeInsets.only(top: 15, bottom: 15, left: 30, right: 30),
        child: Column(
          children: [
            Text(
              'When checking out: ${dc.title}, a crewmember must enter:',
              style: adminTextStyle,
            ),
            ...dc.properties.map((DataProperty dp) {
              if (dp.type == DataType.number) {
                return Text(
                  '${dp.title} (only numbers allowed)',
                  style: adminTextStyle
                );
              }
              return Text(
                '${dp.title}',
                style: adminTextStyle
              );
            }).toList(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _handleEdit(context),
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => _handleDeleteOptionSet(context),
                ),
              ],
            ),
          ]
        ),
      ),
    );
  }
}

/// A form that handles user changes to the admin password.
class ChangeAdminPassword extends StatefulWidget {
  final Function passwordChangeCallback;

  const ChangeAdminPassword({Key key, this.passwordChangeCallback}): super(key: key);

  @override
  ChangeAdminPasswordState createState() {
    return ChangeAdminPasswordState();
  }
}
class ChangeAdminPasswordState extends State<ChangeAdminPassword> {

  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _newPasswordValidateController = TextEditingController();
  String infoText = '';
  bool loadingAfterButtonPress = false;

  initState() {
    super.initState();
  }

  dispose() {
    super.dispose();
  }

  void _handleChangePassword() async {
    /// Validation check.
    if (!_formKey.currentState.validate()) {
      return;
    }

    setState(() {
      loadingAfterButtonPress = true;
      infoText = 'loading...';
    });
    /// Delay a half-second before checking password to give the widget time to
    /// rebuild. Not ideal; ideally, checkPassword should be non-blocking.
    Timer(Duration(milliseconds: 500), () {
      checkPassword(_oldPasswordController.text).then((bool isCorrect) {
        if (!isCorrect) {
          setState(() {
            infoText = 'Incorrect password.';
            loadingAfterButtonPress = false;
          });
          return;
        }
        setState(() {
          infoText = '';
          loadingAfterButtonPress = false;
        });
        updateAdminPassword(_newPasswordController.text).then((s) {
          widget.passwordChangeCallback();
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: <Widget>[
          Divider(),
          TextFormField(
            obscureText: true,
            controller: _oldPasswordController,
            validator: (value) {
              if (value.isEmpty) {
                return 'This field must be filled out.';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Old password',
            ),
          ),
          TextFormField(
            obscureText: true,
            controller: _newPasswordController,
            validator: (value) {
              if (value.isEmpty) {
                return 'This field must be filled out.';
              }
              if (value.length < 5) {
                return 'Password must be at least 5 characters long.';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'New password',
            ),
          ),
          TextFormField(
            obscureText: true,
            controller: _newPasswordValidateController,
            validator: (value) {
              if (value.isEmpty) {
                return 'This field must be filled out.';
              }
              if (value != _newPasswordController.text) {
                return 'Confirm password must match password.';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Admin password',
            ),
          ),
          RaisedButton(
            child: Text(
              'Submit',
              style: adminTextStyle
            ),
            onPressed: loadingAfterButtonPress
              ? null
              : () => _handleChangePassword()
          ),
          Text(
            infoText,
            style: TextStyle(
              fontSize: adminTextStyle.fontSize - 2.0
            )
          ),
          Divider(),
        ],
      )
    );
  }
}

/// A form that handles user additions of option sets.
class AddOptionSet extends StatefulWidget {
  final Function addOptionSetCallback;

  const AddOptionSet({Key key, this.addOptionSetCallback}): super(key: key);

  @override
  AddOptionSetState createState() {
    return AddOptionSetState();
  }
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
    /// Create fields for all properties of the option set. User will be
    /// able to modify a property's name and type (between DataType.string and
    /// DataType.integer) and delete properties.
    List<Widget> propertyFields = [];
    for (int i = 0; i < optionSetPropertyControllers.length; i++) {
      PropertyEntry thisProp = optionSetPropertyControllers[i];
      propertyFields.add(Row(
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
                labelText: 'Option set field',
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

    return Form(
      key: _optionSetFormKey,
      child: Column(
        children: [
          Divider(),
          /// First, create the field where user can define an option set's
          /// name.
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
          ...propertyFields,
          /// Finally, create options for adding more properties to this new
          /// option set, and submission.
          IconButton(
            iconSize: 32,
            icon: Icon(Icons.add_circle_outline),
            onPressed: () => _handleAddOptionSetProperty(),
          ),
          Text(
            'Note: you won\'t need to add properties for check-in and check-out time. These are collected automatically.',
          ),
          RaisedButton(
            onPressed: () => _handleAddOptionSet(),
            child: Text(
              'Submit New Option Set',
              style: adminTextStyle,
            ),
          ),
          Divider(),
        ]
      )
    );
  }
}
