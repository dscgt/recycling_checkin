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
  /// Reference for future that retrieves records indicating a checkout.
  Future<List<Record>> _recordsFuture;

  /// A map of category ID to a Model. For faster metadata lookups,
  /// especially of data category names.
  Map<String, Model> categoriesMeta = {};

  /// Information to display to the user if need be.
  String infoText = '';

  initState() {
    super.initState();
    _recordsFuture = getRecords();
    _getCategoriesMeta();
  }

  _getCategoriesMeta() async {
    try {
      Map<String, Model> categoriesMetaToAdd = {};
      List<Model> dcs = await getCachedCategories();
      dcs.forEach((Model dc) {
        categoriesMetaToAdd[dc.id] = dc;
      });
      setState(() {
        categoriesMeta = categoriesMetaToAdd;
      });
    } catch (e, stack) {
      print(e);
      print(stack);
      setState(() {
        infoText = 'Warning: there was an error retrieving category names. Some'
        ' of this information may look a little jumbled.';
      });
    }
  }

  void _handleConfirmCheckIn(Record record) async {
    /// TODO: handle submission error
    ///   2) checking in when offline results in a future that never finishes
    ///   (Firebase implementation). This is the reason this asynchronous call
    ///   is not handled like it should. Could lead to unexpected behavior
    ///   down the line.
    await checkin(record);

    Navigator.of(context).pop(ConfirmAction.CONFIRM);

    /// After a check-in, refresh record data by restarting FutureBuilder's
    /// future.
    setState(() {
      _recordsFuture = getRecords();
    });
  }

  void _handleCheckIn(BuildContext context, Record record) async {
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
                        _handleConfirmCheckIn(record);
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

  Widget _buildCard(Record record) {
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
          children: <Widget>[
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(right: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${
                        categoriesMeta[record.modelId] != null
                          ? categoriesMeta[record.modelId].title
                          : record.modelId
                      } checkout',
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
              onPressed: () => _handleCheckIn(context, record),
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
