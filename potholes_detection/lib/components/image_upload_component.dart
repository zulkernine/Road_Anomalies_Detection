import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:potholes_detection/components/AnnomalyLocationsServices.dart';

class UploadIndividualImage extends StatefulWidget {
  final File imageFile;
  final Function delete;
  final String url;
  UploadIndividualImage(
      {required this.imageFile,
      required this.delete,
      this.url = "https://google.com"});

  @override
  _UploadIndividualImageState createState() => _UploadIndividualImageState();
}

class _UploadIndividualImageState extends State<UploadIndividualImage> {
  bool _error = false;
  bool _uploadComplete = false;
  bool _uploadingNow = false;
  double _uploadSize = 0;
  String downloadUrl = "";
  bool processedInBackEnd = false;
  File? processedImage;
  List<String> labels = [];
  int contentLength = 0;
  bool isProcessing = false;
  LocationData? locationData;

  @override
  void initState() {
    super.initState();
    processedImage = null;
    locationData = null;
  }

  Future<void> handleUploadTask(File largeFile) async {
    await _uploadToFirebase(largeFile);
    setState(() {
      isProcessing = true;
    });
    var response = await http.post(Uri.parse(this.widget.url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"file": downloadUrl, "type": "image"}));
    setState(() {
      isProcessing = false;
    });
    if (response.statusCode == 200) {
      var body = jsonDecode(response.body);
      print("Processed response:");
      print(body);
      await firebase_storage.FirebaseStorage.instance
          .refFromURL(downloadUrl)
          .delete();
      this.setState(() {
        processedInBackEnd = true;
        downloadUrl = body["url"] as String;
        print(body["labels"].runtimeType);
        print(body["labels"]);
        for (var s in body["labels"]) labels.add(s.toString());
        // labels = body["labels"] as List<String>;
      });
      updateAnomaly(
        location: LatLng(locationData!.latitude!, locationData!.longitude!),
        anomaliesName: labels.toSet(),
        url: downloadUrl,
      );
    } else {
      print("Backend processing error occured");
      showDialog<String>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Error'),
          content:
              const Text("Backend processing error occurred, please retry."),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, 'OK'),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _uploadToFirebase(File largeFile) async {
    String filename = 'uploads/${largeFile.path.split('/').last}';

    firebase_storage.UploadTask task = firebase_storage.FirebaseStorage.instance
        .ref(filename)
        .putFile(largeFile);

    task.snapshotEvents.listen((firebase_storage.TaskSnapshot snapshot) {
      print('Task state: ${snapshot.state}');
      setState(() {
        _uploadSize =
            ((snapshot.totalBytes / (1024 * 1024)) * 100).round().toDouble() /
                100;
      });
    }, onError: (e) {
      setState(() {
        _error = true;
        _uploadingNow = false;
      });
      print(task.snapshot);

      if (e.code == 'permission-denied') {
        print('User does not have permission to upload to this reference.');
      }
    });

    // We can still optionally use the Future alongside the stream.
    try {
      setState(() {
        _uploadingNow = true;
      });
      await task;
      print('Upload complete.');
      String url = await firebase_storage.FirebaseStorage.instance
          .ref(filename)
          .getDownloadURL();
      setState(() {
        _uploadComplete = true;
        downloadUrl = url;
        _error = false;
      });
    } on firebase_core.FirebaseException catch (e) {
      setState(() {
        _error = true;
      });
      if (e.code == 'permission-denied') {
        print('User does not have permission to upload to this reference.');
      } else {
        print(e);
      }
    } finally {
      setState(() {
        _uploadingNow = false;
      });
    }
  }

  Future<File> _loadImage() async {
    var filename = DateTime.now().microsecondsSinceEpoch.toString() + ".png";
    var httpClient = new HttpClient();

    String dir = (await getTemporaryDirectory()).path;
    File file = new File('$dir/$filename');

    var request = await httpClient.getUrl(Uri.parse(downloadUrl));
    var response = await request.close();
    setState(() {
      contentLength = response.contentLength;
    });
    var bytes = await consolidateHttpClientResponseBytes(response);
    await file.writeAsBytes(bytes);
    setState(() {
      processedImage = file;
    });
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(10),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: Colors.white.withOpacity(0.7),
          border:
              Border.all(color: Color.fromRGBO(223, 225, 229, 1.0), width: 1)),
      child: Column(
        children: [
          processedInBackEnd
              ? (processedImage == null
                  ? FutureBuilder(
                      future: _loadImage(),
                      builder: (ctx, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          // If we got an error
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                '${snapshot.error} occured',
                                style: TextStyle(fontSize: 18),
                              ),
                            );

                            // if we got our data
                          } else if (snapshot.hasData) {
                            // Extracting data from snapshot object
                            final data = snapshot.data as File;
                            return Image.file(data);
                          }
                        }

                        // Displaying LoadingSpinner to indicate waiting state
                        return Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                    )
                  : Image.file(processedImage!))
              : Image.file(widget.imageFile),
          (labels.length != 0)
              ? Text("Found: " +
                  labels.join(", ") +
                  "\nSize: " +
                  (contentLength / 1048576).toStringAsPrecision(6) +
                  " MB")
              : Container(),
          Row(
            children: [
              if (_uploadComplete)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SelectableText(
                    "Uploaded Successfully!",
                  ),
                )
              else if (_uploadingNow)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      CircularProgressIndicator(
                        backgroundColor: Colors.tealAccent,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text("Size: $_uploadSize MB"),
                      )
                    ],
                  ),
                )
              else
                Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.all<Color>(Colors.green),
                      ),
                      onPressed: () async {
                        if (this.widget.url.length < 26) {
                          showDialog<String>(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              title: const Text('Insert key'),
                              content: const Text("Can't upload without key"),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.pop(context, 'OK'),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        } else {
                          try {
                            var loc = await Location().getLocation();
                            setState(() {
                              locationData = loc;
                            });
                            await handleUploadTask(this.widget.imageFile);
                          } catch (error) {
                            print(error);
                          }
                        }
                      },
                      child: Row(
                        children: [
                          Icon(Icons.cloud_upload),
                          Padding(
                            padding: const EdgeInsets.only(left: 5.0),
                            child: Text("Upload"),
                          )
                        ],
                      ),
                    )),
              if (_error)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Failed to Upload :(\nTry again!",
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all<Color>(Colors.red),
                  ),
                  onPressed: () {
                    this.widget.delete(this.widget.imageFile);
                  },
                  child: Row(
                    children: [
                      Icon(Icons.delete),
                      Padding(
                        padding: const EdgeInsets.only(left: 5.0),
                        child: Text("Delete"),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
          if (isProcessing)
            Padding(
              padding: EdgeInsets.all(15),
              child: Text("Please wait while processing the image ....."),
            )
        ],
      ),
    );
  }
}

class PotholesDetector extends CustomPainter {
  final ui.Image image;
  final List<Rect>? holes;
  PotholesDetector(this.image, this.holes);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());

    final myPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    if (holes != null) {
      for (var hole in holes!) {
        canvas.drawRect(hole, myPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PotholesDetector oldDelegate) =>
      (image != oldDelegate.image || holes != oldDelegate.holes);
}
