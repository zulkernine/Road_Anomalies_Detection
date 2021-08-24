import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:potholes_detection/components/video_upload_and_play.dart';
import 'package:video_player/video_player.dart';
import './components/AnnomalyLocationsServices.dart';

class LiveMap extends StatefulWidget {
  @override
  _LiveMapState createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  // Completer<GoogleMapController> mapController = Completer();
  final Set<Marker> _markers = <Marker>{};
  Stream<QuerySnapshot<Map<String, dynamic>>>? stream;

  Anomalies anomalies = Anomalies();
  Map<LatLng, Anomaly> marker_positions = Map();

  static const LatLng _center =
      const LatLng(22.496695803485945, 88.37183921981813);

  @override
  void initState() {
    super.initState();
    stream =
        FirebaseFirestore.instance.collection("road_anomalies2").snapshots();
    stream?.listen((event) {
      event.docs.forEach((element) {
        Anomaly anomaly = Anomaly.fromJson(element.data());
        marker_positions[anomaly.position] = anomaly;
      });
      setMarkers();
      print("Listening to stream firestore");
      print(anomalies.toJson());
    });
  }

  @override
  void dispose() {
    super.dispose();
    // stream
  }

  //filler function for test
  void filler() async {
    Anomaly anomaly = Anomaly(
        LatLng(22.497609030317413, 88.3714513907),
        <String>["Wet pothole", "Uneven surface"].toSet(),
        "https://picsum.photos/id/237/200/300");

    print("Updating firestore");
    print(anomaly.toJson());
    CollectionReference ref =
        FirebaseFirestore.instance.collection("road_anomalies2");
    await ref
        .doc(anomaly.position.longitude.toString() +
            anomaly.position.latitude.toString())
        .set(anomaly.toJson());
    print("Completed updating firestore");

    anomaly = Anomaly(
        LatLng(22.496695803485945, 88.37183921981813),
        <String>[
          "Dry pothole",
        ].toSet(),
        "https://picsum.photos/id/410/200/300");

    print("Updating firestore");
    print(anomaly.toJson());
    await ref
        .doc(anomaly.position.longitude.toString() +
            anomaly.position.latitude.toString())
        .set(anomaly.toJson());
    print("Completed updating firestore");
  }

  void _onMapCreated(GoogleMapController controller) {
    // setState(() {
    // mapController.complete(controller);
    // });
  }

  void setMarkers() async {
    for (LatLng l in marker_positions.keys) {
      final Uint8List markerIcond =
          await getBytesFromCanvas(40, marker_positions[l]!.names);
      Marker m = new Marker(
        markerId: MarkerId(l.latitude.toString() + l.longitude.toString()),
        icon: BitmapDescriptor.fromBytes(markerIcond),
        position: l,
        infoWindow: InfoWindow(
          title: "",
        ),
        onTap: () => {
          setState(() {
            showModalBottomSheet(
              context: context,

              builder: (BuildContext context) {
                return Container(
                  width: MediaQuery.of(context).size.width * 0.90,
                  padding: EdgeInsets.all(20),
                  margin: EdgeInsets.all(5),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        //Location
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Latitude"),
                                Text(
                                  "${l.latitude.toStringAsFixed(8)}",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Longitude"),
                                Text(
                                  "${l.longitude.toStringAsFixed(8)}",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                          ],
                        ),

                        SizedBox(
                          height: 20,
                        ),
                        //Anomalies
                        Text(
                          "Anomalies:",
                          style: TextStyle(fontSize: 15),
                        ),
                        Text(
                          marker_positions[l]!.names.join(", "),
                          style: TextStyle(fontSize: 20),
                        ),
                        SizedBox(
                          height: 20,
                        ),

                        //Source link
                        Text(
                          "You may download the processed " +
                              marker_positions[l]!.sourceType +
                              " here: ",
                          style: TextStyle(fontSize: 10),
                        ),
                        ElevatedButton(
                            onPressed: () async {
                              await canLaunch(marker_positions[l]!.sourceUrl)
                                  ? await launch(marker_positions[l]!.sourceUrl)
                                  : print("Can't launch url");
                            },
                            child: Text("Download the source " +
                                marker_positions[l]!.sourceType)),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Or copy the URL",
                                style:
                                    TextStyle(fontSize: 17),
                              ),
                              flex: 9,
                            ),
                            Expanded(
                              child: IconButton(
                                  icon: Icon(Icons.copy),
                                  onPressed: () async {
                                    await Clipboard.setData(new ClipboardData(
                                        text: marker_positions[l]!.sourceUrl));
                                  }),
                              flex: 1,
                            ),
                          ],
                        ),

                        SizedBox(
                          height: 20,
                        ),
                        if (marker_positions[l]!.sourceType == "image")
                          Image.network(
                            marker_positions[l]!.sourceUrl,
                            fit: BoxFit.fill,
                            loadingBuilder: (BuildContext context, Widget child,
                                ImageChunkEvent? loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                          )
                        else
                          ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PlayVideo(
                                      videoPlayerController:
                                          VideoPlayerController.network(
                                              marker_positions[l]!.sourceUrl),
                                      autoplay: false,
                                      looping: false,
                                    ),
                                  ),
                                );
                              },
                              child: Text("Play")),
                      ],
                    ),
                  ),
                );
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
              ),
              backgroundColor: Colors.white,
            );
          })
        },
      );
      this.setState(() {
        _markers.add(m);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print(anomalies.wet_potholes);
    return Scaffold(
      backgroundColor: Colors.white70,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Google map"),
      ),
      body: SafeArea(
        child: ListView(
          itemExtent: MediaQuery.of(context).size.height,
          children: [
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 17.0,
              ),
              markers: _markers.toSet(),
              //Following attribute is set to avoid map crash on three finger gesture
              gestureRecognizers: Set()
                ..add(
                    Factory<PanGestureRecognizer>(() => PanGestureRecognizer()))
                ..add(Factory<ScaleGestureRecognizer>(
                    () => ScaleGestureRecognizer()))
                ..add(
                    Factory<TapGestureRecognizer>(() => TapGestureRecognizer()))
                ..add(Factory<VerticalDragGestureRecognizer>(
                    () => VerticalDragGestureRecognizer())),
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // filler();
          showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.90,
                padding: EdgeInsets.all(20),
                margin: EdgeInsets.all(5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Legends",
                          style: TextStyle(
                            fontSize: 25.0,
                          ),
                        )
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Image.asset("assets/dry_pothole.png"),
                          flex: 2,
                        ),
                        Expanded(
                          child: Container(),
                          flex: 1,
                        ),
                        Expanded(
                          child: Text(
                            "Dry pothole",
                            style: TextStyle(
                              fontSize: 20.0,
                            ),
                          ),
                          flex: 8,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Image.asset("assets/manhole.png"),
                          flex: 2,
                        ),
                        Expanded(
                          child: Container(),
                          flex: 1,
                        ),
                        Expanded(
                          child: Text(
                            "Manhole",
                            style: TextStyle(
                              fontSize: 20.0,
                            ),
                          ),
                          flex: 8,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Image.asset("assets/speed_breaker.png"),
                          flex: 2,
                        ),
                        Expanded(
                          child: Container(),
                          flex: 1,
                        ),
                        Expanded(
                          child: Text(
                            "Speed breaker",
                            style: TextStyle(
                              fontSize: 20.0,
                            ),
                          ),
                          flex: 8,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Image.asset("assets/uneven_surface.png"),
                          flex: 2,
                        ),
                        Expanded(
                          child: Container(),
                          flex: 1,
                        ),
                        Expanded(
                          child: Text(
                            "Uneven surface",
                            style: TextStyle(
                              fontSize: 20.0,
                            ),
                          ),
                          flex: 8,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Image.asset("assets/wet_pothole.png"),
                          flex: 2,
                        ),
                        Expanded(
                          child: Container(),
                          flex: 1,
                        ),
                        Expanded(
                          child: Text(
                            "Wet pothole",
                            style: TextStyle(
                              fontSize: 20.0,
                            ),
                          ),
                          flex: 8,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
            ),
            backgroundColor: Colors.white,
          );
        },
        child: Icon(Icons.legend_toggle),
      ),
    );
  }
}

Future<Uint8List> getBytesFromCanvas(int height, Set<String> anomalies) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  final Paint paint = Paint()..color = Colors.lightBlueAccent;
  final Paint borderPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round;
  final Radius radius = Radius.circular(8.0);
  canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0.0, 0.0, (height * anomalies.length + 16).toDouble(),
            (height + 16).toDouble()),
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: radius,
      ),
      paint);
  canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0.0, 0.0, (height * anomalies.length + 16).toDouble(),
            (height + 16).toDouble()),
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: radius,
      ),
      borderPaint);
  final Paint linePaint = Paint()
    ..color = Colors.black
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 4;
  canvas.drawLine(Offset((height / 2 + 8.0), (height + 16).toDouble()),
      Offset((height / 2 + 8.0), height * 3.0 + 16), linePaint);

  int i = 0;
  for (String anomaly in anomalies) {
    if (anomaly == "Uneven surface") {
      final ByteData datai = await rootBundle.load("assets/uneven_surface.png");
      var imaged = await loadImage(new Uint8List.view(datai.buffer), height);
      canvas.drawImage(
          imaged, new Offset((i * height + 8).toDouble(), 8), new Paint());
      i++;
    }
    if (anomaly == "Wet pothole") {
      final ByteData datai = await rootBundle.load("assets/wet_pothole.png");
      var imaged = await loadImage(new Uint8List.view(datai.buffer), height);
      canvas.drawImage(
          imaged, new Offset((i * height + 8).toDouble(), 8), new Paint());
      i++;
    }
    if (anomaly == "Speed breaker") {
      final ByteData datai = await rootBundle.load("assets/speed_breaker.png");
      var imaged = await loadImage(new Uint8List.view(datai.buffer), height);
      canvas.drawImage(
          imaged, new Offset((i * height + 8).toDouble(), 8), new Paint());
      i++;
    }
    if (anomaly == "Manholes") {
      final ByteData datai = await rootBundle.load("assets/manhole.png");
      var imaged = await loadImage(new Uint8List.view(datai.buffer), height);
      canvas.drawImage(
          imaged, new Offset((i * height + 8).toDouble(), 8), new Paint());
      i++;
    }
    if (anomaly == "Dry pothole") {
      final ByteData datai = await rootBundle.load("assets/dry_pothole.png");
      var imaged = await loadImage(new Uint8List.view(datai.buffer), height);
      canvas.drawImage(
          imaged, new Offset((i * height + 8).toDouble(), 8), new Paint());
      i++;
    }
  }

  final img = await pictureRecorder
      .endRecording()
      .toImage((height * anomalies.length + 16), (height * 1.5 + 16).toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<ui.Image> loadImage(Uint8List data, int height) async {
  img.Image baseSizeImage = img.decodeImage(data)!;
  img.Image resizeImage =
      img.copyResize(baseSizeImage, height: height, width: height);
  ui.Codec codec = await ui
      .instantiateImageCodec(Uint8List.fromList(img.encodePng(resizeImage)));
  ui.FrameInfo frameInfo = await codec.getNextFrame();
  return frameInfo.image;
}
