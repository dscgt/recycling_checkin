import 'package:flutter/material.dart';
import 'package:recycling_checkin/api.dart';
import 'package:recycling_checkin/classes.dart';

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

  @override
  void initState() {
    widget.record.model.fields
      .where((ModelField mf) => mf.delay)
      .forEach((ModelField mf) {
        controllers[mf.title] = TextEditingController();
      });
    super.initState();
  }

  void close() {
    Navigator.pop(context);
  }

  void _handleConfirmCheckIn(BuildContext context) async {
    // Create CheckedOutRecord with the controllers' values for submission
    CheckedOutRecord toSubmit = CheckedOutRecord(
      model: widget.record.model,
      id: widget.record.id,
      record: Record.fromRecord(widget.record.record)
    );
    toSubmit.record.properties.addAll(controllers.map((String s, TextEditingController tec) =>
      MapEntry(s, tec.text)
    ));

    /// TODO: handle submission error
    ///   2) checking in when offline results in a future that never finishes
    ///   (Firebase implementation). This is the reason this asynchronous call
    ///   is not handled like it should. Could lead to unexpected behavior
    ///   down the line.
    await checkin(toSubmit);
    Navigator.of(context).pop(ConfirmAction.CONFIRM);
    close();
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
    showDialog<ConfirmAction>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool loadingAfterButtonPress = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Are you sure you want to check this in?'),
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
                    : () {
                        setState(() {
                          loadingAfterButtonPress = true;
                        });
                        _handleConfirmCheckIn(context);
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
    List<Widget> formInputs = widget.record.model.fields
      .where((ModelField mf) => mf.delay)
      .map((ModelField mf) {
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