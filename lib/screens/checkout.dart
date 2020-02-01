import 'package:flutter/material.dart';
import 'package:recycling_checkin/api.dart';
import 'package:recycling_checkin/classes.dart';

class CheckOut extends StatefulWidget {
  @override
  CheckOutState createState() {
    return CheckOutState();
  }
}

class CheckOutState extends State<CheckOut> {
  bool loading = true;

  /// The checkout types (ex. Vehicle, Fuel Card) available to the user for
  /// selection.
  List<String> availableTypes = [];

  /// A record of checkout type -> checkout property (ex. Vehicle #, Name,
  /// any detail relevant to a checkout) -> form of that property (ex. string,
  /// number).
  Map<String, Map<String, dynamic>> availablePropertiesMeta = {};

  /// The type of checkout selected by the user. Defaults to the first checkout
  /// type retrieved.
  String checkoutType;

  /// Checkout details entered by the user. Defaults to all empty inputs.
  Map<String, Map<String, dynamic>> availableProperties = {};


  @override
  void initState() {
    getCategories().then((List<DataCategory> categories) {

      // build state objects from retrieved categories

      List<String> theseAvailableTypes = categories.map((DataCategory dc)  => dc.title).toList();

      Map<String, Map<String, dynamic>> theseAvailablePropertiesMeta = {};
      categories.forEach((DataCategory dc) {
        theseAvailablePropertiesMeta[dc.title] = {};
        dc.properties.forEach((DataProperty dp) {
          theseAvailablePropertiesMeta[dc.title][dp.title] = dp.type;
        });
      });

      Map<String, Map<String, dynamic>> theseAvailableProperties = {};
      categories.forEach((DataCategory dc) {
        theseAvailableProperties[dc.title] = {};
        dc.properties.forEach((DataProperty dp) {
          theseAvailableProperties[dc.title][dp.title] = null;
        });
      });

      // Still have to setState inside asynchronous code to trigger UI rebuild,
      // even within initState()
      setState(() {
        availableTypes = theseAvailableTypes;
        availablePropertiesMeta = theseAvailablePropertiesMeta;
        checkoutType = availableTypes.length > 0
          ? availableTypes[0]
          : null;
        availableProperties = theseAvailableProperties;
        loading = false;
      });
    });

    super.initState();
  }

  void clearInputs() {
    setState(() {
      availableProperties.forEach((String category, Map<String, dynamic> property) {
        property.keys.forEach((String propertyTitle) {
          availableProperties[category][propertyTitle] = null;
        });
      });
    });
  }

  _handleSubmitRecord() async {
    Record thisRecord = Record(
      type: checkoutType,
      properties: availableProperties[checkoutType]
    );

    await submitRecord(thisRecord);
    clearInputs();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Text('Loading...');
    }

    Widget fields = Column(
      children: availableProperties[checkoutType].entries.map((MapEntry e) {
        String propertyTitle = e.key;
        if (availablePropertiesMeta[checkoutType][propertyTitle] == DataType.string) {
          return Row(
            children: <Widget>[
              Text('$propertyTitle: '),
              Expanded(
                child: TextField(
                  onSubmitted: (String value) { _handleSubmitRecord(); },
                  onChanged: (text) {
                    // do not use setState; this doesn't need to trigger a UI rebuild
                    availableProperties[checkoutType][propertyTitle] = text;
                  },
                )
              ),
            ],
          );
        } else {
          // do nothing for now
          return Text('UNDER CONSTRUCTION');
        }

      }).toList()
    );

    return Column(
      children: [
        DropdownButton<String>(
          value: checkoutType,
          icon: Icon(Icons.arrow_drop_down),
          onChanged: (String newValue) {
            setState(() {
              checkoutType = newValue;
            });
          },
          items: availableTypes.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            )
          ).toList(),
        ),
        fields,
        RaisedButton(
          onPressed: () => _handleSubmitRecord(),
          child: Text('Check out')
        )
      ]
    );
  }
}
