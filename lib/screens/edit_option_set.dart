import 'package:flutter/material.dart';
import 'package:recycling_checkin/api.dart';
import 'package:recycling_checkin/classes.dart';

TextStyle adminTextStyle = TextStyle(
  fontSize: 18.0
);

class EditOptionSet extends StatefulWidget {
  final DataCategory dataCategory;

  EditOptionSet({Key key, this.dataCategory}): super(key: key);

  @override
  EditOptionSetState createState() {
    return EditOptionSetState();
  }
}
class EditOptionSetState extends State<EditOptionSet> {

  List<PropertyEntry> optionSetPropertyControllers = [];
  final _optionSetFormKey = GlobalKey<FormState>();
  final _optionSetNameController = TextEditingController();

  @override
  void initState() {
    /// Get the DataCategory title from given DataCategory, and set as initial
    /// value within the form.
    _optionSetNameController.text = widget.dataCategory.title;

    /// Create form elements about DataCategory properties from given
    /// DataCategory.
    optionSetPropertyControllers = widget.dataCategory.properties.map((DataProperty dp) {
      TextEditingController thisController = TextEditingController();
      thisController.text = dp.title;
      return PropertyEntry(
        controller: thisController,
        type: dp.type
      );
    }).toList();

    super.initState();
  }

  _handleAddOptionSetProperty() {
    setState(() {
      optionSetPropertyControllers.add(PropertyEntry(
        controller: TextEditingController(),
        type: DataType.string
      ));
    });
  }

  _handleEditSubmit(BuildContext context) async {
    if (!_optionSetFormKey.currentState.validate()) {
      return;
    }
    DataCategory toAdd = DataCategory(
      title: _optionSetNameController.text,
      properties: optionSetPropertyControllers.map((PropertyEntry pe) {
        return DataProperty(
          title: pe.controller.text,
          type: pe.type
        );
      }).toList()
    );
    await updateDataCategory(widget.dataCategory.id, toAdd);
    Navigator.pop(context);
  }

  dispose() {
    _optionSetNameController.dispose();
    optionSetPropertyControllers.forEach((PropertyEntry pe) {
      pe.controller.dispose();
    });
    super.dispose();
  }

  Widget build(BuildContext context) {
    /// Create fields for all properties of the option set. User will be
    /// able to modify a property's name and type (between DataType.string and
    /// DataType.integer) and delete properties.
    List<Widget> propertyFields = [];
    for (int i = 0; i < optionSetPropertyControllers.length; i++) {
      PropertyEntry thisProp = optionSetPropertyControllers[i];
      propertyFields.add(Row(
        children: <Widget>[
          Expanded(
            child: TextFormField(
              controller: thisProp.controller,
              validator: (value) {
                if (value.isEmpty) {
                  return 'This field must be filled out.';
                }
                return null;
              },
              decoration: const InputDecoration(
                hintText: 'A required detail (ex. name)',
                labelText: 'Option set field',
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle_outline),
            onPressed: () {
              setState(() {
                optionSetPropertyControllers.removeAt(i);
              });
            },
          ),
          Checkbox(
              onChanged: (bool checked) {
                setState(() {
                  optionSetPropertyControllers[i].type = checked
                      ? DataType.number
                      : DataType.string;
                });
              },
              value: thisProp.type == DataType.number
          ),
          Text('Only allow numbers')
        ],
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.dataCategory.title}')
      ),
      body: Container(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Form(
            key: _optionSetFormKey,
            child: Column(
              children: [
                /// First, create the field where user can define an option set's
                /// name.
                TextFormField(
                  controller: _optionSetNameController,
                  validator: (value) {
                    if (value.isEmpty) {
                      return 'This field must be filled out.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'A broad check-out category (ex. Vehicle, Fuel Card...)',
                    labelText: 'Option set name',
                  ),
                ),
                ...propertyFields,
                /// Finally, create options for adding more properties to this new
                /// option set, and submission.
                IconButton(
                  iconSize: 32,
                  icon: Icon(Icons.add_circle_outline),
                  onPressed: () => _handleAddOptionSetProperty(),
                ),
                Text(
                  'Note: you won\'t need to add properties for check-in and check-out time. These are handled automatically.',
                ),
                RaisedButton(
                  onPressed: () => _handleEditSubmit(context),
                  child: Text(
                    'Submit',
                    style: adminTextStyle,
                  ),
                ),
              ]
            )
          )
        )
      )
    );
  }
}