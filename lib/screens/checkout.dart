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

  /// A record of checkout type -> DataCategory. For fast lookups of data
  /// category metadata.
  Map<String, DataCategory> checkoutMeta = {};

  /// A record of checkout type -> checkout property (ex. Vehicle #, Name,
  /// any detail relevant to a checkout) -> DataProperty. For fast lookups
  /// about data category's properties' metadata.
  Map<String, Map<String, DataProperty>> checkoutPropertiesMeta = {};

  /// The type of checkout selected by the user. Defaults to the first checkout
  /// type retrieved.
  String checkoutType;

  /// Checkout details entered by the user. Defaults to all empty inputs.
  Map<String, Map<String, TextEditingController>> checkoutProperties = {};

  /// Form key for the dynamically generated form. May be applied to different
  /// forms.
  final _formKey = GlobalKey<FormState>();

  /// Information to display to the user if needed.
  String infoText = '';

  @override
  void initState() {
    super.initState();
    attemptGetCategories();
  }

  attemptGetCategories() async {
    List<DataCategory> categories;
    try {
      categories = await getCategories();
      initCategoriesState(categories);
    } catch (e, stack) {
      print(e);
      print(stack);
      try {
        categories = await getCachedCategories();
        /// By now, getting categories from cloud DB failed, so we succesfully
        /// retrieved categories from local cache.
        initCategoriesState(categories);
        setState(() {
          loading = false;
          infoText = 'Warning: There was a problem getting the most recent checkout options. The options you see may be outdated.';
        });
      } catch (e, stack) {
        print(e);
        print(stack);
        /// By now, getting categories from cloud DB failed, and getting
        /// categories from local cache failed as well.
        setState(() {
          loading = false;
          infoText = 'ERROR: There was an error: ${e.toString()}';
        });
      }
    }
  }

  void initCategoriesState(List<DataCategory> categories) {
    // build state objects from retrieved categories
    List<String> theseAvailableTypes = categories.map((DataCategory dc)  => dc.title).toList();
    Map<String, DataCategory> theseCheckoutMeta = {};
    categories.forEach((DataCategory dc) {
      theseCheckoutMeta[dc.title] = dc;
    });
    Map<String, Map<String, DataProperty>> theseAvailablePropertiesMeta = {};
    categories.forEach((DataCategory dc) {
      theseAvailablePropertiesMeta[dc.title] = {};
      dc.properties.forEach((DataProperty dp) {
        theseAvailablePropertiesMeta[dc.title][dp.title] = dp;
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
      checkoutMeta = theseCheckoutMeta;
      checkoutPropertiesMeta = theseAvailablePropertiesMeta;
      checkoutType = availableTypes.length > 0
          ? availableTypes[0]
          : null;
      checkoutProperties = theseAvailableProperties;
      loading = false;
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
      categoryId: checkoutMeta[checkoutType].id,
      properties: theseProperties
    );
    /// TODO: Handle submisson errors
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

    Widget informationText = Text(
      infoText,
      style: TextStyle(
        fontSize: 16.0,
        color: Colors.red
      )
    );

    if (availableTypes.length == 0) {
      return Container(
        padding: EdgeInsets.only(left: 75.0, right: 75.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            informationText,
            Container(
              padding: EdgeInsets.only(top: 20.0),
              child: Text('There aren\'t any things to checkout. If you believe this is in error, please contact your administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24.0
                ),
              )
            )
          ],
        )
      );
    }

    List<Widget> formElements = [];
    checkoutProperties[checkoutType].forEach((String propertyTitle, TextEditingController te) {
      TextInputType thisKeyboardType = TextInputType.text;
      if (checkoutPropertiesMeta[checkoutType][propertyTitle].type == DataType.number) {
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
      padding: EdgeInsets.only(left: 75.0, right: 75.0, top: 20.0),
      child: Column(
        children: [
          informationText,
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
