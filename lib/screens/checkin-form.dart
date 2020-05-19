import 'package:flutter/material.dart';
import 'package:recycling_checkin/api.dart';
import 'package:recycling_checkin/classes.dart';
import 'package:recycling_checkin/screens/loading.dart';

enum ConfirmAction { CANCEL, CONFIRM }

class CheckInForm extends StatefulWidget {
  final CheckedOutRecord record;

  CheckInForm({
    Key key,
    this.record,
  }) : super(key: key);

  @override
  CheckInFormState createState() {
    return CheckInFormState();
  }
}

class CheckInFormState extends State<CheckInForm> {

  /// Form key for the dynamically generated form.
  final _formKey = GlobalKey<FormState>();
  /// A map of ModelField title to controller. Contains controllers for all
  /// ModelField's to be submitted by this widget.
  Map<String, TextEditingController> controllers = {};
  /// Field values entered by the user, for fields that need a dropdown
  Map<String, String> fieldsForDropdown = {};
  /// A record of groupId -> Group. For fast lookups about groups.
  Map<String, Group> groupsMeta = {};
  bool loading = true;
  String infoText = '';

  @override
  void initState() {
    attemptGetGroups();

    super.initState();
  }

  void close() {
    Navigator.pop(context);
  }

  void attemptGetGroups() async {
    List<Group> groups;
    try {
      groups = await getGroups();
      initControllersAndMeta(groups);
    } catch (e, stack) {
      print(e);
      print(stack);
      try {
        groups = await getCachedGroups();
        // By now, getting groups from cloud DB failed, so we successfully
        // retrieved groups from local cache.
        initControllersAndMeta(groups);
        setState(() {
          infoText = 'Warning: There was a problem getting the most recent options. The options you see may be outdated.';
        });
      } catch (e, stack) {
        print(e);
        print(stack);
        // By now, getting models from cloud DB failed, and getting
        // models from local cache failed as well.
        initControllersAndMeta(null);
      }
    }

  }

  void initControllersAndMeta(List<Group> groups) {
    Map<String, TextEditingController> controllersToSet = {};
    Map<String, Group> groupsMetaToSet = {};
    if (groups != null) {
      groups.forEach((Group group) {
        groupsMetaToSet[group.id] = group;
      });
    }
    widget.record.model.fields
      .where((ModelField mf) => mf.delay)
      .forEach((ModelField mf) {
        if (!(mf.type == ModelFieldDataType.select && groupsMetaToSet[mf.groupId] != null)) {
          controllersToSet[mf.title] = TextEditingController();
        }
      });

    setState(() {
      controllers = controllersToSet;
      groupsMeta = groupsMetaToSet;
      loading = false;
    });
  }

  Future<void> _handleConfirmCheckIn(BuildContext context) async {
    // Create CheckedOutRecord with the controllers' values for submission
    CheckedOutRecord toSubmit = CheckedOutRecord(
      model: widget.record.model,
      id: widget.record.id,
      record: Record.fromRecord(widget.record.record)
    );
    toSubmit.record.properties.addAll(controllers.map((String s, TextEditingController tec) =>
      MapEntry(s, tec.text)
    ));
    toSubmit.record.properties.addAll(fieldsForDropdown.map((String s1, String s2) =>
      MapEntry(s1, s2)
    ));
    await checkin(toSubmit);
  }

  void _handleCancelPressed() {
    showDialog<ConfirmAction>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure you want to cancel?'),
          actions: <Widget>[
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.CANCEL);
              },
              child: const Text('NO'),
            ),
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.CONFIRM);
                close();
              },
              child: const Text('YES'),
            ),
          ],
        );
      }
    );
  }

  void _handleCheckInPressed() async {
    if (!_formKey.currentState.validate()) {
      return;
    }

    showDialog<ConfirmAction>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool loadingAfterButtonPress = false;
        String infoText = '';
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Are you sure you want to check this in?'),
              content: infoText.length > 0
                ? Container(
                    child: Text(
                      infoText,
                      style: TextStyle(
                        color: Colors.red,
                      ),
                    )
                  )
                : null,
              actions: <Widget>[
                FlatButton(
                  onPressed: loadingAfterButtonPress
                    ? null
                    : () {
                        Navigator.of(context).pop(ConfirmAction.CANCEL);
                      },
                  child: const Text('CANCEL'),
                ),
                FlatButton(
                  onPressed: loadingAfterButtonPress
                    ? null
                    : () async {
                        setState(() {
                          loadingAfterButtonPress = true;
                        });
                        try {
                          await _handleConfirmCheckIn(context);
                          Navigator.of(context).pop(ConfirmAction.CONFIRM);
                          close();
                        } catch (e, st) {
                          print('Check-in form error');
                          print(e);
                          print(st);
                          setState(() {
                            infoText = 'Something went wrong. Hit \'CONFIRM\' to try again after a bit. Write your checkout down and contact your manager if the problem keeps happening.';
                            loadingAfterButtonPress = false;
                          });
                        }
                      },
                  child: const Text('CONFIRM'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Loading();
    }

    List<Widget> formInputs = widget.record.model.fields
      .where((ModelField mf) => mf.delay)
      .map((ModelField mf) {
        // Handle fields requiring a dropdown, but only if field uses a
        // dropdown group that exists.
        if (mf.type == ModelFieldDataType.select
            && groupsMeta[mf.groupId] != null) {
          return DropdownButtonFormField<String>(
            validator: (String value) {
              if (value == null && !mf.optional) {
                return 'Please enter a ${mf.title}.';
              }
              return null;
            },
            value: fieldsForDropdown[mf.title],
            hint: Text(mf.title),
            icon: Icon(Icons.arrow_drop_down),
            onChanged: (String newValue) {
              setState(() {
                fieldsForDropdown[mf.title] = newValue;
              });
            },
            items: groupsMeta[mf.groupId].members.map((String member) =>
              DropdownMenuItem<String>(
                value: member,
                child: Text(member)
              )
            ).toList(),
          );
        } else {
          TextInputType thisKeyboardType = TextInputType.text;
          if (mf.type == ModelFieldDataType.number) {
            thisKeyboardType = TextInputType.number;
          }
          return TextFormField(
            controller: controllers[mf.title],
            validator: (value) {
              if (value.isEmpty && !mf.optional) {
                return 'Please enter a ${mf.title}';
              }
              return null;
            },
            keyboardType: thisKeyboardType,
            decoration: InputDecoration(
                labelText: '${mf.title}${mf.optional ? ' (optional)' : ''}'
            ),
          );
        }
      })
      .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Finish ${widget.record.model.title} check-in'),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        padding: EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              Text(
                infoText,
                style: TextStyle(
                  fontSize: 16.0,
                  color: Colors.red
                )
              ),
              ...formInputs,
              Padding(padding: EdgeInsets.only(top: 10)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  RaisedButton(
                    onPressed: () => _handleCancelPressed(),
                    child: Text('Cancel')
                  ),
                  Padding(padding: EdgeInsets.only(left: 5, right: 5)),
                  RaisedButton(
                    onPressed: () => _handleCheckInPressed(),
                    child: Text('Finish Check-In')
                  ),
                ],
              )
            ],
          ),
        ),
      )
    );
  }
}