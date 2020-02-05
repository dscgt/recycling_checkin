import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    super.initState();
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
      return Text('Loading...');
    }

    List<Widget> formElements = [];
    checkoutProperties[checkoutType].forEach((String propertyTitle, TextEditingController te) {
      TextInputType thisKeyboardType = TextInputType.text;
      if (checkoutPropertiesMeta[checkoutType][propertyTitle] == DataType.number) {
        thisKeyboardType = TextInputType.number;
      }
      formElements.add(
        Row(
          children: <Widget>[
            Text('$propertyTitle: '),
            Expanded(
              child: TextFormField(
                controller: checkoutProperties[checkoutType][propertyTitle],
                validator: (value) {
                  if (value.isEmpty) {
                    return 'Please enter a $propertyTitle.';
                  }
                  return null;
                },
                keyboardType: thisKeyboardType
              )
            ),
          ],
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
        Form(
          key: _formKey,
          child: Column(
            children: formElements
          )
        ),
      ]
    );
  }
}
