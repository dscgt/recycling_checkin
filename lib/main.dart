// Invoke "debug painting" (press "p" in the console, choose the
// "Toggle Debug Paint" action from the Flutter Inspector in Android
// Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
// to see the wireframe for each widget.
//
// local data storage:
// https://flutter.dev/docs/cookbook/persistence/sqlite

import 'package:flutter/material.dart';
import 'package:recycling_checkin/screens/checkin.dart';
import 'package:recycling_checkin/screens/checkout.dart';

void main() {
  runApp(App());
}

class App extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Check Out',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Main(),
    );
  }
}

class Main extends StatefulWidget {
  Main({Key key}) : super(key: key);
  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> {

  /// The ID of the screen to display. 0 is checkout, 1 is checkin.
  int _view = 0;

  _handleTapNavigation(int index) {
    setState(() {
      _view = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget toDisplay;
    String appBarText;
    if (_view == 1) {
      toDisplay = CheckIn();
      appBarText = 'Check In';
    } else { // view is 0, or defaults to it
      toDisplay = CheckOut();
      appBarText = 'Check Out';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarText),
      ),
      body: toDisplay,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            title: Text('Check Out'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check),
            title: Text('Check In'),
          ),
        ],
        currentIndex: _view,
        onTap: _handleTapNavigation,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Color.fromARGB(255, 200, 200, 200),
        showUnselectedLabels: true,
      ),
    );
  }
}
