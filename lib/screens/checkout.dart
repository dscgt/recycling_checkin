import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:recycling_checkin/api.dart';
import 'package:recycling_checkin/classes.dart';
import 'package:recycling_checkin/screens/loading.dart';

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
  Map<String, Map<String, dynamic>> checkoutPropertiesMeta = {};

  /// The type of checkout selected by the user. Defaults to the first checkout
  /// type retrieved.
  String checkoutType;

  /// Checkout details entered by the user. Defaults to all empty inputs.
  Map<String, Map<String, TextEditingController>> checkoutProperties = {};

  /// Form key for the dynamically generated form. May be applied to different
  /// forms.
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
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

      Map<String, Map<String, TextEditingController>> theseAvailableProperties = {};
      categories.forEach((DataCategory dc) {
        theseAvailableProperties[dc.title] = {};
        dc.properties.forEach((DataProperty dp) {
          TextEditingController thisController = TextEditingController();
          theseAvailableProperties[dc.title][dp.title] = thisController;
        });
      });

      // Still have to setState inside asynchronous code to trigger UI rebuild,
      // even within initState()
      setState(() {
        availableTypes = theseAvailableTypes;
        checkoutPropertiesMeta = theseAvailablePropertiesMeta;
        checkoutType = availableTypes.length > 0
          ? availableTypes[0]
          : null;
        checkoutProperties = theseAvailableProperties;
        loading = false;
      });
    });
  }

  void dispose() {
    // Dispose of all TextEditingController's.
    checkoutProperties.forEach((String key, Map<String, TextEditingController> tec) {
      tec.forEach((String key2, TextEditingController tec2) {
        tec2.dispose();
      });
    });

    super.dispose();
  }

  void clearForm() {
    setState(() {
      checkoutProperties[checkoutType].keys.forEach((String propertyTitle) {
        checkoutProperties[checkoutType][propertyTitle].clear();
      });
    });
  }

  _handleSubmitRecord() async {
    if (!_formKey.currentState.validate()) {
      return;
    }

    Map<String, dynamic> theseProperties = {};
    checkoutProperties[checkoutType].forEach((String propertyName, TextEditingController te) {
      theseProperties[propertyName] = te.text;
    });
    Record thisRecord = Record(
      category: checkoutType,
      properties: theseProperties
    );
    await checkout(thisRecord);
    Scaffold.of(context).showSnackBar(
      SnackBar(
        content: Text('Checkout submitted')
      )
    );
    clearForm();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Loading();
    }

    if (availableTypes.length == 0) {
      return Container(
        alignment: Alignment.center,
        padding: EdgeInsets.only(left: 75.0, right: 75.0),
        child: Text('There aren\'t any things to checkout. If you believe this is in error, please contact your administrator.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24.0
          ),
        )
      );
    }

    List<Widget> formElements = [];
    checkoutProperties[checkoutType].forEach((String propertyTitle, TextEditingController te) {
      TextInputType thisKeyboardType = TextInputType.text;
      if (checkoutPropertiesMeta[checkoutType][propertyTitle] == DataType.number) {
        thisKeyboardType = TextInputType.number;
      }
      formElements.add(
        TextFormField(
          controller: checkoutProperties[checkoutType][propertyTitle],
          validator: (value) {
            if (value.isEmpty) {
              return 'Please enter a $propertyTitle.';
            }
            return null;
          },
          keyboardType: thisKeyboardType,
          decoration: InputDecoration(
            labelText: '$propertyTitle'
          ),
        )
      );
    });
    formElements.addAll([
      RaisedButton(
        onPressed: () => _handleSubmitRecord(),
        child: Text('Check out')
      ),
      Text('(Date and time will be recorded automatically.)')
    ]);

    return Container(
      padding: EdgeInsets.only(left: 75.0, right: 75.0),
      child: Column(
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
          Form(
            key: _formKey,
            child: Column(
              children: formElements
            )
          ),
        ]
      )
    );
  }
}
