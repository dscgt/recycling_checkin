import 'dart:async';
import 'package:flutter/material.dart';
import 'package:recycling_checkin/classes.dart';
import 'package:recycling_checkin/screens/admin.dart';
import 'package:recycling_checkin/screens/admin_login.dart';

/// Parent widget to OptionSetList and AddOptionSet. Handles visibility of
/// option set adding form,
class AdminBuilder extends StatefulWidget {

  @override
  AdminBuilderState createState() {
    return AdminBuilderState();
  }
}
class AdminBuilderState extends State<AdminBuilder> {

  final StreamController<AdminAuthenticationState> _streamController =
      StreamController<AdminAuthenticationState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _streamController.close();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminAuthenticationState>(
      stream: _streamController.stream,
      initialData: AdminAuthenticationState.NO,
      builder: (BuildContext context, AsyncSnapshot<AdminAuthenticationState> snapshot) {
        AdminAuthenticationState state = snapshot.data;
        if (state == AdminAuthenticationState.NO) {
          return AdminLogin(
            adminAuthController: _streamController
          );
        } else { // state == AdminAuthenticationState.YES
          return Admin(
            adminAuthController: _streamController
          );
        }
      }
    );
  }
}