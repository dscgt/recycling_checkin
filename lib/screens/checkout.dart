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

  /// The models(ex. Vehicle, Fuel Card) available to the user for
  /// selection.
  List<Model> availableTypes = [];
  /// The model selected by the user.
  Model selectedModel;

  /// A record of model title -> model field title (ex. Vehicle #, Name))
  /// -> ModelField. For fast lookups about data category's properties'
  /// metadata.
  Map<String, Map<String, ModelField>> checkoutPropertiesMeta = {};

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
    List<Model> categories;
    try {
      /// By now, we have successfully retrieved categories from cloud DB.
      categories = await getCategories();
      initCategoriesState(categories);
    } catch (e, stack) {
      print(e);
      print(stack);
      try {
        categories = await getCachedCategories();
        /// By now, getting categories from cloud DB failed, so we successfully
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

  void initCategoriesState(List<Model> categories) {
    // build state objects from retrieved categories.
    Map<String, Map<String, ModelField>> theseAvailablePropertiesMeta = {};
    categories.forEach((Model dc) {
      theseAvailablePropertiesMeta[dc.title] = {};
      dc.fields.forEach((ModelField dp) {
        theseAvailablePropertiesMeta[dc.title][dp.title] = dp;
      });
    });
    Map<String, Map<String, TextEditingController>> theseAvailableProperties = {};
    categories.forEach((Model dc) {
      theseAvailableProperties[dc.title] = {};
      dc.fields.forEach((ModelField dp) {
        TextEditingController thisController = TextEditingController();
        theseAvailableProperties[dc.title][dp.title] = thisController;
      });
    });

    // Still have to setState inside asynchronous code to trigger UI rebuild,
    // even within initState()
    setState(() {
      availableTypes = categories;
      checkoutPropertiesMeta = theseAvailablePropertiesMeta;
      selectedModel = availableTypes.length > 0
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
      checkoutProperties[selectedModel.title].keys.forEach((String propertyTitle) {
        checkoutProperties[selectedModel.title][propertyTitle].clear();
      });
    });
  }

  _handleSubmitRecord() async {
    if (!_formKey.currentState.validate()) {
      return;
    }

    Map<String, dynamic> theseProperties = {};
    checkoutProperties[selectedModel.title].forEach((String propertyName, TextEditingController te) {
      theseProperties[propertyName] = te.text;
    });
    Record thisRecord = Record(
      modelId: selectedModel.id,
      modelTitle: selectedModel.title,
      properties: theseProperties
    );
    /// TODO: Handle submisson errors
    await checkout(CheckedOutRecord(
      record: thisRecord,
      model: selectedModel
    ));
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

    List<Widget> formInputs = [];
    List<String> delayedFields = [];
    checkoutProperties[selectedModel.title].forEach((String propertyTitle, TextEditingController te) {
      if (checkoutPropertiesMeta[selectedModel.title][propertyTitle].delay) {
        // Skip if this is a field meant to be completed later.
        delayedFields.add(propertyTitle);
        return;
      }
      TextInputType thisKeyboardType = TextInputType.text;
      if (checkoutPropertiesMeta[selectedModel.title][propertyTitle].type == ModelFieldDataType.number) {
        thisKeyboardType = TextInputType.number;
      }
      bool isOptional = checkoutPropertiesMeta[selectedModel.title][propertyTitle].optional;
      formInputs.add(
        TextFormField(
          controller: checkoutProperties[selectedModel.title][propertyTitle],
          validator: (value) {
            if (value.isEmpty && !isOptional) {
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

    return Container(
      padding: EdgeInsets.only(left: 75.0, right: 75.0, top: 20.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            informationText,
            DropdownButton<Model>(
              value: selectedModel,
              icon: Icon(Icons.arrow_drop_down),
              onChanged: (Model newValue) {
                setState(() {
                  selectedModel = newValue;
                });
              },
              items: availableTypes.map<DropdownMenuItem<Model>>((Model value) => DropdownMenuItem<Model>(
                  value: value,
                  child: Text(value.title),
                )
              ).toList(),
            ),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  ...formInputs,
                  Padding(padding: EdgeInsets.only(top: 10)),
                  Text(delayedFields.length > 0
                    ? 'Later, you\'ll be asked to fill out: ${delayedFields.join(', ')}.'
                    : ''
                  ),
                  Text('Date and time will be recorded automatically.'),
                  RaisedButton(
                    onPressed: () => _handleSubmitRecord(),
                    child: Text('Check out')
                  ),
                ]
              )
            ),
          ]
        ),
      )
    );
  }
}
