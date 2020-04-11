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
  List<Model> models = [];
  /// The model selected by the user.
  Model selectedModel;

  /// A record of model title -> model field title (ex. Vehicle #, Name))
  /// -> ModelField. For fast lookups about models' properties'
  /// metadata. Also a master list of all fields.
  Map<String, Map<String, ModelField>> fieldsMeta = {};
  /// A record of groupId -> Group. For fast lookups about groups.
  Map<String, Group> groupsMeta = {};

  /// Field values entered by the user. Defaults to all empty inputs. For fields
  /// that need a textbox and are not delayed.
  Map<String, Map<String, TextEditingController>> fields = {};
  /// Field values entered by the user, for fields that need a dropdown and are
  /// not delayed.
  Map<String, Map<String, String>> fieldsForDropdown = {};

  /// Form key for the dynamically generated form. May be applied to different
  /// forms.
  final _formKey = GlobalKey<FormState>();

  /// Information to display to the user if needed.
  String infoText = '';

  @override
  void initState() {
    super.initState();
    attemptGetModelsAndGroups();
  }

  attemptGetModelsAndGroups() async {
    List<Model> models;
    List<Group> groups;
    try {
      /// By now, we have successfully retrieved models from cloud DB.
      models = await getModels();
      groups = await getGroups();
      initModelsState(models, groups);
    } catch (e, stack) {
      print(e);
      print(stack);
      try {
        models = await getCachedModels();
        groups = await getCachedGroups();
        /// By now, getting models from cloud DB failed, so we successfully
        /// retrieved models from local cache.
        initModelsState(models, groups);
        setState(() {
          loading = false;
          infoText = 'Warning: There was a problem getting the most recent checkout options. The options you see may be outdated.';
        });
      } catch (e, stack) {
        print(e);
        print(stack);
        /// By now, getting models from cloud DB failed, and getting
        /// models from local cache failed as well.
        setState(() {
          loading = false;
          infoText = 'ERROR: There was an error: ${e.toString()}';
        });
      }
    }
  }

  void initModelsState(List<Model> theseModels, List<Group> groups) {
    // build state objects from retrieved theseModels.
    Map<String, Map<String, ModelField>> fieldsMetaToSet = {};
    theseModels.forEach((Model dc) {
      fieldsMetaToSet[dc.title] = {};
      dc.fields.forEach((ModelField dp) {
        fieldsMetaToSet[dc.title][dp.title] = dp;
      });
    });
    Map<String, Group> groupsMetaToSet = {};
    groups.forEach((Group g) {
      groupsMetaToSet[g.id] = g;
    });
    Map<String, Map<String, TextEditingController>> fieldsToSet = {};
    Map<String, Map<String, String>> fieldsForDropdownToSet = {};
    theseModels.forEach((Model dc) {
      fieldsToSet[dc.title] = {};
      fieldsForDropdownToSet[dc.title] = {};
      dc.fields.forEach((ModelField dp) {
        // skip delay fields
        if (dp.delay) {
          return;
        }
        if (dp.type != ModelFieldDataType.select) {
          TextEditingController thisController = TextEditingController();
          fieldsToSet[dc.title][dp.title] = thisController;
        }
      });
    });

    setState(() {
      models = theseModels;
      fieldsMeta = fieldsMetaToSet;
      groupsMeta = groupsMetaToSet;
      fieldsForDropdown = fieldsForDropdownToSet;
      selectedModel = models.length > 0
          ? models[0]
          : null;
      fields = fieldsToSet;
      loading = false;
    });
  }

  void dispose() {
    // Dispose of all TextEditingController's.
    fields.forEach((String key, Map<String, TextEditingController> tec) {
      tec.forEach((String key2, TextEditingController tec2) {
        tec2.dispose();
      });
    });

    super.dispose();
  }

  void clearForm() {
    setState(() {
      fields[selectedModel.title].keys.forEach((String propertyTitle) {
        fields[selectedModel.title][propertyTitle].clear();
      });
      fieldsForDropdown[selectedModel.title].keys.forEach((String propertyTitle) {
        fieldsForDropdown[selectedModel.title][propertyTitle] = null;
      });
    });
  }

  _handleSubmitRecord() async {
    if (!_formKey.currentState.validate()) {
      return;
    }

    Map<String, dynamic> theseProperties = {};
    fields[selectedModel.title].forEach((String propertyName, TextEditingController te) {
      theseProperties[propertyName] = te.text;
    });
    fieldsForDropdown[selectedModel.title].forEach((String propertyName, String value) {
      theseProperties[propertyName] = value;
    });
    Record thisRecord = Record(
      modelId: selectedModel.id,
      modelTitle: selectedModel.title,
      properties: theseProperties
    );
    try {
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
    } catch (e, st) {
      print('Checkout submission error happened');
      print(e);
      print(st);
      Scaffold.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong. Try again after a bit. Write your checkout down and contact your manager if the problem keeps happening.')
        )
      );
    }
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

    if (models.length == 0) {
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
    fieldsMeta[selectedModel.title].keys.forEach((String propertyTitle) {
      ModelField thisFieldMeta = fieldsMeta[selectedModel.title][propertyTitle];
      // collect delay fields for display to user and skip their building
      if (thisFieldMeta.delay) {
        delayedFields.add(thisFieldMeta.title);
        return;
      }

      if (thisFieldMeta.type == ModelFieldDataType.select) {
        formInputs.add(
          DropdownButtonFormField<String>(
            validator: (String value) {
              if (value == null && !thisFieldMeta.optional) {
                return 'Please enter a $propertyTitle.';
              }
              return null;
            },
            value: fieldsForDropdown[selectedModel.title][propertyTitle],
            hint: Text(propertyTitle),
            icon: Icon(Icons.arrow_drop_down),
            onChanged: (String newValue) {
              setState(() {
                fieldsForDropdown[selectedModel.title][propertyTitle] = newValue;
              });
            },
            items: groupsMeta[thisFieldMeta.groupId].members.map((String member) =>
              DropdownMenuItem<String>(
                value: member,
                child: Text(member)
              )
            ).toList(),
          )
        );
      } else {
        TextInputType thisKeyboardType = TextInputType.text;
        if (thisFieldMeta.type == ModelFieldDataType.number) {
          thisKeyboardType = TextInputType.number;
        }
        bool isOptional = thisFieldMeta.optional;
        formInputs.add(
          TextFormField(
            controller: fields[selectedModel.title][propertyTitle],
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
      }
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
              items: models.map<DropdownMenuItem<Model>>((Model value) => DropdownMenuItem<Model>(
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
