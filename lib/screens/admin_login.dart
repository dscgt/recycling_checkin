import 'dart:async';

import 'package:flutter/material.dart';
import 'package:recycling_checkin/classes.dart';
import 'package:recycling_checkin/screens/loading.dart';

import '../api.dart';

class AdminLogin extends StatefulWidget {
  final StreamController<AdminAuthenticationState> adminAuthController;

  const AdminLogin({Key key, this.adminAuthController}): super(key: key);

  @override
  AdminLoginState createState() {
    return AdminLoginState();
  }
}

class AdminLoginState extends State<AdminLogin> {

  final _loginFormKey = GlobalKey<FormState>();
  final _adminInitializeFormKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool loadingAfterButtonPress = false;
  String infoText = '';
  Future<bool> _checkAdminPasswordExistsFuture = checkIfPasswordExists();

  void _handleAdminAuth() {
    if (!_loginFormKey.currentState.validate()) {
      return;
    }
    setState(() {
      loadingAfterButtonPress = true;
      infoText = 'loading...';
    });
    /// Delay a half-second before checking password to give the widget time to
    /// rebuild. Not ideal; ideally, checkPassword should be non-blocking.
    Timer(Duration(milliseconds: 500), () {
      checkPassword(_passwordController.text).then((bool isCorrect) {
        if (!isCorrect) {
          setState(() {
            infoText = 'Incorrect password.';
            loadingAfterButtonPress = false;
          });
          return;
        }
        setState(() {
          infoText = '';
          loadingAfterButtonPress = false;
        });
        widget.adminAuthController.add(AdminAuthenticationState.YES);
      });
    });
  }

  void _handleAdminInitializePassword() {
    if (!_adminInitializeFormKey.currentState.validate()) {
      return;
    }

    setState(() {
      loadingAfterButtonPress = true;
      infoText = 'loading...';
    });
    /// Delay a half-second before checking password to give the widget time to
    /// rebuild. Not ideal; ideally, checkPassword should be non-blocking.
    Timer(Duration(milliseconds: 500), () {
      // TODO: handle error
      updateAdminPassword(_newPasswordController.text).then((void v) {
        setState(() {
          infoText = '';
          loadingAfterButtonPress = false;
          _checkAdminPasswordExistsFuture = checkIfPasswordExists();
        });
      });
    });

  }

  Widget _buildAdminInitializeForm(BuildContext context) {
    return Form(
      key: _adminInitializeFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('No admin password has been set up yet. Please enter a password to be used to access the admin page.'
            'You can change this at a later.'),
          TextFormField(
            obscureText: true,
            controller: _newPasswordController,
            validator: (value) {
              if (value.isEmpty) {
                return 'This field must be filled out.';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'New admin password',
            ),
          ),
          RaisedButton(
            child: Text('Submit'),
            onPressed: loadingAfterButtonPress
              ? null
              : () => _handleAdminInitializePassword()
          ),
          Text(infoText),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _checkAdminPasswordExistsFuture,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (!snapshot.hasData) {
          return Loading();
        }
        if (snapshot.data == false) {
          return _buildAdminInitializeForm(context);
        }
        return Container(
          padding: EdgeInsets.only(left: 75.0, right: 75.0),
          child: Form(
            key: _loginFormKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextFormField(
                  obscureText: true,
                  controller: _passwordController,
                  validator: (value) {
                    if (value.isEmpty) {
                      return 'This field must be filled out.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Admin password',
                  ),
                ),
                RaisedButton(
                  child: Text('Submit'),
                  onPressed: loadingAfterButtonPress
                    ? null
                    : () => _handleAdminAuth()
                ),
                Text(infoText),
              ],
            )
          ),
        );
      }
    );

  }
}
