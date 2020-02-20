import 'dart:async';

import 'package:flutter/material.dart';
import 'package:recycling_checkin/classes.dart';

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

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool loadingAfterButtonPress = false;
  String infoText = '';

  void _handleAdminAuth() {
    if (!_formKey.currentState.validate()) {
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Form(
        key: _formKey,
        child: Column(
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
}
