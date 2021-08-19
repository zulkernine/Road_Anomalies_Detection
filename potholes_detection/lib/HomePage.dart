import 'package:flutter/material.dart';

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
        constraints: BoxConstraints.expand(),
        decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/background_road.png"),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Colors.blue.withOpacity(0.35), BlendMode.dstATop),
            )),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SelectableText(
                  'Through this app, we try to track and locate anomalies on the road. User will take picture/video and upload to server.' +
                      'Device will automatically fetch location. Then processed data will be stored. If anomalies are found, that location ' +
                      'will be marked on the map with corresponding anomaly-icon',
                  style: TextStyle(fontSize: 20.0),
                ),
                SizedBox(
                  height: 25,
                ),
                Text(
                  "In the map section, tap the floating button on bottom right to see legends.",
                  style: TextStyle(fontSize: 20.0),
                )
              ],
            ),
          ),
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
