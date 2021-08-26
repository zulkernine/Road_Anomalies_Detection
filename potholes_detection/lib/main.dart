import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'dart:io';

import 'UploadImage.dart';
import 'LiveMap.dart';
import 'HomePage.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;
  UserCredential? userCredential;
  bool _error = false;
  String _error_message = "Something went wrong!\nPlease restart the app";

  //States value for UploadImage()
  List<File> _images = [];
  List<Map<String, String>> _videoes = <Map<String, String>>[];
  String processedVideoUrl = "";
  String server_url = "";
  Map<int, LatLng> path_coordinate = {};

  var pageList = <Widget>[];
  int currentPaeIndex = 0;

  final bottomNavigationItems = [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.cloud_upload), label: 'Upload'),
    BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
  ];

  void updateServerUrl(String url) {
    setState(() {
      server_url = url;
    });
  }

  void onTapBottomNavigation(int index) {
    setState(() {
      currentPaeIndex = index;
    });
  }

  void initializeFlutterFire() async {
    try {
      // Wait for Firebase to initialize and set `_initialized` state to true
      await Firebase.initializeApp();
      userCredential = await FirebaseAuth.instance.signInAnonymously();
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      // Set `_error` state to true if Firebase initialization fails
      setState(() {
        _error = true;
      });
      print(e);
    }
  }

  void checkLocationPermission() async {
    Location location = new Location();
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        setState(() {
          _error = true;
          _error_message =
              "We can't Work without location service :(, Enable it, give permission and reopen the app.";
        });
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        setState(() {
          _error = true;
          _error_message =
              "We can't Work without location service :(, Enable it, give permission and reopen the app.";
        });
      }
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    initializeFlutterFire();
    checkLocationPermission();
    pageList.add(MyHomePage(title: "Road Anomalies"));
    pageList.add(UploadImage(
      images: _images,
      url: server_url,
      videoes: _videoes,
      path: path_coordinate,
      updateServerUrl: updateServerUrl,
      processedVideoUrl: processedVideoUrl,
    ));
    pageList.add(LiveMap());
    // pageList.add(LiveMap());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return MaterialApp(
        home: SafeArea(
          child: Scaffold(
            body: Center(
              child: Container(
                child: Text(_error_message),
              ),
            ),
          ),
        ),
      );
    }

    // Show a loader until FlutterFire is initialized
    if (!_initialized) {
      return MaterialApp(
        home: SafeArea(
          child: Center(
            child: Container(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: SafeArea(
        child: Scaffold(
          body: IndexedStack(
            children: pageList,
            index: currentPaeIndex,
          ),
          bottomNavigationBar: BottomNavigationBar(
            type : BottomNavigationBarType.fixed,
            items: bottomNavigationItems,
            currentIndex: currentPaeIndex,
            onTap: onTapBottomNavigation,
          ),
        ),
      ),
    );
  }
}
