import 'dart:ffi';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:potholes_detection/components/video_upload_and_play.dart';
import 'package:video_compress/video_compress.dart';
import 'dart:io';

import './components/image_upload_component.dart';

class UploadImage extends StatefulWidget {
  final List<File> images;
  final File? videoes;
  final String processedVideoUrl;
  final String url;
  final Map<int, LatLng> path;

  UploadImage(
      {required this.images,
      required this.url,
      required this.videoes,
      required this.path,
      required this.processedVideoUrl});

  @override
  _UploadImageState createState() => _UploadImageState();
}

class _UploadImageState extends State<UploadImage> {
  List<File> _images = [];
  File? _videoes = null;
  String url = "";
  bool recordingNow = false;
  Map<int, LatLng> path = {};

  @override
  void initState() {
    super.initState();
    _images = this.widget.images;
    _videoes = widget.videoes;
    url = widget.url;
    path = widget.path;
    Location().onLocationChanged.listen((LocationData currentLocation) {
      if (recordingNow) {
        path[DateTime.now().millisecondsSinceEpoch] =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);
      }
    });
  }

  Future getImage(bool gallery, BuildContext context) async {
    if (!await _getKey(context)) return;

    ImagePicker picker = ImagePicker();
    PickedFile? pickedFile;
    // Let user select photo from gallery
    if (gallery) {
      pickedFile = await picker.getImage(
          source: ImageSource.gallery,
          maxHeight: 512,
          maxWidth: 512,
          imageQuality: 60);
    }
    // Otherwise open camera to get new photo
    else {
      pickedFile =
          await picker.getImage(source: ImageSource.camera, imageQuality: 50);
    }

    setState(() {
      if (pickedFile != null) {
        _images.add(File(pickedFile.path));
      } else {
        print('No image selected.');
      }
    });
  }

  Future getVideo(bool gallery, BuildContext context) async {
    if (!await _getKey(context)) return;

    ImagePicker picker = ImagePicker();
    PickedFile? pickedFile;
    // Let user select photo from gallery
    if (gallery) {
      pickedFile = await picker.getVideo(
        source: ImageSource.gallery,
      );
    }
    // Otherwise open camera to get new photo
    else {
      var loc = await Location().getLocation();
      setState(() {
        path[DateTime.now().millisecondsSinceEpoch] =
            LatLng(loc.latitude!, loc.longitude!);
        recordingNow = true;
      });
      pickedFile = await picker.getVideo(
        source: ImageSource.camera,
      );
      loc = await Location().getLocation();
      setState(() {
        recordingNow = false;
        path[DateTime.now().millisecondsSinceEpoch] =
            LatLng(loc.latitude!, loc.longitude!);
      });
      // print(File(pickedFile!.path).lastModifiedSync());
    }
    MediaInfo? mediaInfo;
    if (pickedFile != null) {
      mediaInfo = await VideoCompress.compressVideo(
        pickedFile.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false, // It's false by default
        includeAudio: false,
        frameRate: 17,
      );
    }

    setState(() {
      if (mediaInfo != null) {
        _videoes = mediaInfo.file;
      } else {
        print('No Video selected.');
      }
    });
  }

  deleteImage(File img, {bool isVideo = false}) {
    setState(() {
      if (isVideo) {
        _videoes = null;
      } else {
        _images.remove(img);
      }
    });
  }

  Future<bool> _getKey(BuildContext context) async {
    bool key = false, isBlank = true;

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Input the key'),
            content: TextField(
              onChanged: (String value) {
                this.setState(() {
                  url = "https://$value.ngrok.io/predict";
                  isBlank = (value == "");
                });
              },
              decoration: InputDecoration(
                  hintText: "KEY", helperText: "KEY can not be empty"),
            ),
            actions: <Widget>[
              ElevatedButton(
                child: Text('CANCEL'),
                style: ElevatedButton.styleFrom(primary: Colors.red),
                onPressed: () {
                  key = false;
                  setState(() {
                    Navigator.pop(context);
                  });
                },
              ),
              ElevatedButton(
                child: Text('OK'),
                onPressed: () {
                  key = true;
                  if (!isBlank) {
                    setState(() {
                      Navigator.pop(context);
                    });
                  }
                },
              ),
            ],
          );
        });
    return key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white70,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text("Upload Image"),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [

                ElevatedButton(
                  onPressed: () {
                    getImage(false, context);
                  },
                  child: Row(
                    children: [
                      Icon(Icons.image),
                      Padding(
                        padding: const EdgeInsets.only(left: 5.0),
                        child: Text("Image"),
                      )
                    ],
                  ),
                ),
                (_images.length == 0)
                    ? Center(
                        child: Image.asset("assets/taking_picture.png"),
                      )
                    : Column(
                        children: [
                          for (var img in _images)
                            UploadIndividualImage(
                              imageFile: img,
                              delete: deleteImage,
                              url: url,
                            )
                        ],
                      ),

                ElevatedButton(
                  onPressed: () {
                    getVideo(false, context);
                  },
                  child: Row(
                    children: [
                      Icon(Icons.videocam),
                      Padding(
                        padding: const EdgeInsets.only(left: 5.0),
                        child: Text("Video"),
                      )
                    ],
                  ),
                ),
                _videoes == null
                    ? Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Image.asset("assets/video_taking.png"),
                      )
                    : UploadIndividualVideo(
                        imageFile: _videoes!,
                        delete: deleteImage,
                        url: url,
                        path: path,
                        processedVideoUrl: widget.processedVideoUrl,
                      ),
                VideoCompress.isCompressing
                    ? Center(
                        child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            Text("Compressing the video"),
                          ],
                        ),
                      ))
                    : Container(),
              ],
            ),
          ),
        ));
  }
}
