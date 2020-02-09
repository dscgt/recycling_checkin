import 'package:flutter/material.dart';
import 'package:recycling_checkin/api.dart';
import 'package:recycling_checkin/classes.dart';
import 'package:recycling_checkin/utils.dart';

class CheckIn extends StatefulWidget {
  @override
  CheckInState createState() {
    return CheckInState();
  }
}

class CheckInState extends State<CheckIn> {
  int something = 0;

  handleCheckIn(String recordId) async {
    await checkin(recordId);

    /// After checking in, get new record data by calling an empty setState--
    /// this will trigger a rebuild and refresh FutureBuilder's future. Not
    /// ideal; ideally, we sidestep this entirely with a StreamBuilder, but
    /// Sembast doesn't support stream-based pulling.
    setState(() {});
  }

  Widget buildCard(Record record) {
    if (record.id == null) {
      throw new RangeError('Record without an ID retrieved. Cannot be rendered.');
    }

    List<Widget> propsToDisplay = [];
    record.properties.forEach((String key, dynamic value) {
      if (value is String) {
        propsToDisplay.add(
          Text('$key: $value')
        );
      }
    });

    return Card(
      child: Row(
        children: <Widget>[
          Column(
            children: <Widget>[
              Text(
                '${record.category} checkout',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                )
              ),
              Column(
                children: propsToDisplay,
              ),
              Text('Checked out at: ${dateTimeToString(record.checkoutTime)}'),
            ],
          ),
          RaisedButton(
            onPressed: () => handleCheckIn(record.id),
            child: Text('Check In')
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Record>>(
      future: getRecords(true),
      builder: (BuildContext context, AsyncSnapshot<List<Record>> snapshot) {
        if (snapshot.hasData) {
          if(snapshot.data.length == 0) {
            return Text('Nothing\'s checked out. If you believe this is an error, record your checkin on paper and contact your manager.');
          }
          return Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: snapshot.data.map(buildCard).toList()
                ),
              )
            ],
          );
        } else {
          return Text('Loading...');
        }
      }
    );
  }
}
