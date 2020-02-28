import 'package:flutter/material.dart';
import 'package:recycling_checkin/api.dart';
import 'package:recycling_checkin/classes.dart';
import 'package:recycling_checkin/screens/loading.dart';
import 'package:recycling_checkin/utils.dart';

class Records extends StatefulWidget {
  @override
  RecordsState createState() {
    return RecordsState();
  }
}

class RecordsState extends State<Records> {
  static const String ALL_CATEGORIES_FILTER_NAME = 'All categories';
  static const String SORT_BY_OLDEST_NAME = 'Oldest';
  static const String SORT_BY_NEWEST_NAME = 'Newest';

  Future<List<Record>> _recordsFuture;
  String categoryFilter = ALL_CATEGORIES_FILTER_NAME;
  String sortFilter = SORT_BY_NEWEST_NAME;
  bool includeCheckedOut = false;

  initState() {
    super.initState();

    _recordsFuture = getRecords();
  }

  /// Builds a dropdown with categories extracted from [records].
  Widget _buildCategoryDropdown(List<Record> records) {
    List<String> categories = [ALL_CATEGORIES_FILTER_NAME];
    records.forEach((Record r) {
      if (categories.indexOf(r.category) == -1) {
        categories.add(r.category);
      }
    });
    return DropdownButton<String>(
      value: categoryFilter,
      icon: Icon(Icons.arrow_drop_down),
      onChanged: (String newValue) {
        setState(() {
          categoryFilter = newValue;
        });
      },
      items: categories.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(
        value: value,
        child: Text(value),
      )).toList(),
    );
  }

  Widget _buildRecords(BuildContext context, List<Record> records) {
    TextStyle cardTextStyle = TextStyle(
      fontSize: 18.0
    );

    // remove records that don't match user-specified category
    // does not remove any records if user has chosen to view all categories
    List<Record> recordsToDisplay = new List<Record>.from(records);
    if (categoryFilter != ALL_CATEGORIES_FILTER_NAME) {
      recordsToDisplay.removeWhere((Record r) {
        return r.category != categoryFilter;
      });
    }

    // remove records indicating a currently checked-out asset if
    // the user does not wish to see them
    if (!includeCheckedOut) {
      recordsToDisplay.removeWhere((Record r) {
        return !(r.checkinTime is DateTime);
      });
    }

    // sort records by user-specified order
    if (sortFilter == SORT_BY_OLDEST_NAME) {
      recordsToDisplay.sort((Record a, Record b) {
        // if a occurs earlier than b, return negative value to place a in front
        // treat a null checkin time as new
        if (a.checkinTime == null && b.checkinTime == null) {
          return 0;
        }
        if (a.checkinTime == null) {
          return -1;
        }
        if (b.checkinTime == null) {
          return 1;
        }
        return a.checkinTime.compareTo(b.checkinTime);
      });
    } else { // sortFilter == SORT_BY_NEWEST_NAME
      recordsToDisplay.sort((Record b, Record a) {
        // treat a null checkin time as new
        if (a.checkinTime == null && b.checkinTime == null) {
          return 0;
        }
        if (a.checkinTime == null) {
          return -1;
        }
        if (b.checkinTime == null) {
          return 1;
        }
        return a.checkinTime.compareTo(b.checkinTime);
      });
    }

    return ListView.builder(
      itemCount: recordsToDisplay.length,
      itemBuilder: (BuildContext context, int index) {
        Record thisRecord = recordsToDisplay[index];

        List<Widget> propsToDisplay = [];
        thisRecord.properties.forEach((String key, dynamic value) {
          if (value is String) {
            propsToDisplay.add(
              Text(
                '$key: $value',
                style: cardTextStyle
              )
            );
          }
        });
        return Card(
          child: Container(
            padding: const EdgeInsets.only(
              top: 10.0,
              bottom: 10.0,
              right: 20.0,
              left: 20.0
            ),
            child: Column(
              children: <Widget>[
                Text('${thisRecord.category} checkout',
                  style: cardTextStyle.copyWith(
                    fontWeight: FontWeight.bold
                  )
                ),
                Column(
                  children: propsToDisplay,
                ),
                Text(
                  'Checked out at: ${dateTimeToString(thisRecord.checkoutTime)}',
                  style: cardTextStyle
                ),
                Text('Checked in at: ${thisRecord.checkinTime is DateTime
                  ? dateTimeToString(thisRecord.checkinTime)
                  : 'Not checked in yet'
                }',
                  style: cardTextStyle
                )
              ],
            ),
          )
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _recordsFuture,
      builder: (BuildContext context, AsyncSnapshot<List<Record>> snapshot) {
        if (!snapshot.hasData) {
          return Loading();
        }
        return Container(
          padding: const EdgeInsets.only(top: 10.0, bottom: 10.0, left: 20.0, right: 20.0),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  DropdownButton<String>(
                    value: sortFilter,
                    icon: Icon(Icons.arrow_drop_down),
                    onChanged: (String newValue) {
                      setState(() {
                        sortFilter = newValue;
                      });
                    },
                    items: [
                      SORT_BY_NEWEST_NAME,
                      SORT_BY_OLDEST_NAME,
                    ].map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      )
                    ).toList(),
                  ),
                  Container(
                    padding: const EdgeInsets.only(left: 15.0, right: 15.0),
                    child: _buildCategoryDropdown(snapshot.data),
                  ),
                  Row(
                    children: <Widget>[
                      Checkbox(
                        onChanged: (bool newValue) {
                          setState(() {
                            includeCheckedOut = newValue;
                          });
                        },
                        value: includeCheckedOut
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          includeCheckedOut = !includeCheckedOut;
                        }),
                        child: Text('Include currently checked-out'),
                      )
                    ],
                  )
                ],
              ),
              Expanded(
                child: _buildRecords(context, snapshot.data)
              )
            ],
          )
        );
      }
    );
  }
}
