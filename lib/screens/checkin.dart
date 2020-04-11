import 'package:flutter/material.dart';
import 'package:recycling_checkin/api.dart';
import 'package:recycling_checkin/classes.dart';
import 'package:recycling_checkin/screens/checkin-form.dart';
import 'package:recycling_checkin/screens/loading.dart';
import 'package:recycling_checkin/utils.dart';

final double cardFontSize = 18.0;
enum ConfirmAction { CANCEL, CONFIRM }

class CheckIn extends StatefulWidget {
  @override
  CheckInState createState() {
    return CheckInState();
  }
}

class CheckInState extends State<CheckIn> {
  /// Reference for future that retrieves checkouts.
  Future<List<CheckedOutRecord>> _recordsFuture;

  /// Information to display to the user if need be.
  String infoText = '';

  initState() {
    super.initState();
    _recordsFuture = getRecords();
  }

  void _handleCheckInPressed(CheckedOutRecord record) async {
    /// Redirect user to a check-in form if additional input is needed
    if (record.model.fields
      .where((ModelField mf) => mf.delay)
      .toList().length > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckInForm(
            record: record
          )
        )
      ).then((dynamic d) {
        setState(() {
          _recordsFuture = getRecords();
        });
      });
      return;
    }

    showDialog<ConfirmAction>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool loadingAfterButtonPress = false;
        String infoText = '';
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setInnerState) {
            return AlertDialog(
              title: const Text(
                'Are you sure you want to check this in?',
              ),
              content: infoText.length > 0
                ? Container(
                    child: Text(
                      infoText,
                      style: TextStyle(
                        color: Colors.red,
                      ),
                    )                  )
                : null ,
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
                        setInnerState(() {
                          loadingAfterButtonPress = true;
                        });
                        try {
                          await checkin(record);
                          setState(() {
                            _recordsFuture = getRecords();
                          });
                          Navigator.of(context).pop(ConfirmAction.CONFIRM);
                        } catch (e, st) {
                          print('Check-in error');
                          print(e);
                          print(st);
                          setInnerState(() {
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

  Widget _buildErrorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'Oops! We ran into an error retrieving things currently checked out. Wait'
            ' a bit, then hit "Refresh" below. Contact an administrator if this keeps'
            ' happening.',
            style: TextStyle(
              fontSize: 22.0
            ),
            textAlign: TextAlign.center,
          ),
        ),
        RaisedButton(
          onPressed: () {
            setState(() {
              /// Attempt another retrieval by refreshing records future.
              _recordsFuture = getRecords();
            });
          },
          child: Text(
            'Refresh',
            style: TextStyle(
              fontSize: 16.0
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(CheckedOutRecord record) {
    if (record.id == null) {
      throw new RangeError('Record without an ID retrieved. Cannot be rendered.');
    }

    List<Widget> propsToDisplay = [];
    List<String> delayedFields = record.model.fields
      .where((ModelField mf) => mf.delay)
      .map((ModelField mf) => mf.title)
      .toList();
    record.record.properties.forEach((String key, dynamic value) {
      if (value is String && !delayedFields.contains(key)) {
        propsToDisplay.add(
          Text('$key: $value',
            style: TextStyle(
              fontSize: cardFontSize
            ),
          )
        );
      }
    });
    propsToDisplay.add(
      Text('Checked out at: ${dateTimeToString(record.record.checkoutTime)}',
        style: TextStyle(
          fontSize: cardFontSize
        ),
      )
    );
    if (delayedFields.length > 0) {
      propsToDisplay.add(
        Text(
          'Upon check-in, you\'ll be asked to fill out: ${delayedFields.join(', ')}.',
          style: TextStyle(
            fontSize: cardFontSize,
            fontWeight: FontWeight.bold
          ),
        )
      );
    }

    return Card(
      child: Container(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 15.0, left: 15.0),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(right: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${record.model.title} checkout',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: cardFontSize
                      )
                    ),
                    ...propsToDisplay,
                  ],
                ),
              )
            ),
            RaisedButton(
              onPressed: () => _handleCheckInPressed(record),
              child: Text('Check In',
                style: TextStyle(
                  fontSize: 20.0
                ),
              )
            ),
          ],
        )
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CheckedOutRecord>>(
      future: _recordsFuture,
      builder: (BuildContext context, AsyncSnapshot<List<CheckedOutRecord>> snapshot) {
        if (snapshot.hasError) {
          print(snapshot.error);
          return _buildErrorView();
        } else if (snapshot.hasData) {
          if(snapshot.data.length == 0) {
            return Container(
              alignment: Alignment.center,
              padding: EdgeInsets.only(left: 75.0, right: 75.0),
              child: Text('Nothing\'s checked out. If you believe this is an error, record your checkin on paper and contact your manager.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24.0
                ),
              )
            );
          }
          return Container(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: <Widget>[
                Text(
                  infoText,
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.red
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(bottom: 20.0),
                  child: Text('These are the things that are currently checked out. When you are ready to check an item in, locate your item and tap "Check in".',
                    style: TextStyle(
                      fontSize: 20.0
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: snapshot.data.map(_buildCard).toList()
                  ),
                )
              ],
            )
          );
        } else {
          return Loading();
        }
      }
    );
  }
}
