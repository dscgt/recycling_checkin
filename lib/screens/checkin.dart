/// TODOS:
/// - checkin confirmation box
/// - style admin page and records page--quickly!
/// - error messaging and handling--perhaps a default error page that users are directed to, then when they click they can try to "reload" the page they were on?
/// - handle button mashes

import 'package:flutter/material.dart';
import 'package:recycling_checkin/api.dart';
import 'package:recycling_checkin/classes.dart';
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
  Future<List<Record>> _recordsFuture;

  initState() {
    super.initState();
    _recordsFuture = getRecords(true);
  }

  _handleConfirmCheckIn(String recordId) async {
    await checkin(recordId);
    Navigator.of(context).pop(ConfirmAction.CONFIRM);
    /// After a check-in, refresh record data by restarting FutureBuilder's
    /// future. Not ideal; ideally, we sidestep this entirely with a
    /// StreamBuilder, but Sembast doesn't support stream-based pulling.
    setState(() {
      _recordsFuture = getRecords(true);
    });
  }

  _handleCheckIn(BuildContext context, String recordId) async {
    showDialog<ConfirmAction>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure you want to check this in?'),
          actions: <Widget>[
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.CANCEL);
              },
              child: const Text('CANCEL'),
            ),
            FlatButton(
              onPressed: () => _handleConfirmCheckIn(recordId),
              child: const Text('CONFIRM'),
            ),
          ],
        );
      }
    );
  }

  Widget buildCard(Record record) {
    if (record.id == null) {
      throw new RangeError('Record without an ID retrieved. Cannot be rendered.');
    }

    List<Widget> propsToDisplay = [];
    record.properties.forEach((String key, dynamic value) {
      if (value is String) {
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
      Text('Checked out at: ${dateTimeToString(record.checkoutTime)}',
        style: TextStyle(
          fontSize: cardFontSize
        ),
      )
    );

    return Card(
      child: Container(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, right: 15.0, left: 15.0),
        child: Row(
//          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(right: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${record.category} checkout',
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
              onPressed: () => _handleCheckIn(context, record.id),
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
    return FutureBuilder<List<Record>>(
      future: _recordsFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Record>> snapshot) {
        if (snapshot.hasData) {
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
                    children: snapshot.data.map(buildCard).toList()
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
