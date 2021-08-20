import 'dart:ffi';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:potholes_detection/components/video_upload_and_play.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
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
  // File? _videoes = null;
  List<File> _videoes = [];
  String url = "";
  bool recordingNow = false;
  Map<int, LatLng> path = {};
  bool splittingVideo = false;

  @override
  void initState() {
    super.initState();
    _images = this.widget.images;
    // _videoes = widget.videoes;
    url = widget.url;
    path = widget.path;
    Location().onLocationChanged.listen((LocationData currentLocation) {
      if (recordingNow) {
        path[DateTime.now().millisecondsSinceEpoch] =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);
      }
    });
  }

  Future getImage(bool gallery) async {
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

  Future getVideo(bool gallery) async {
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
        frameRate: 30,
      );
    }

    setState(() {
      splittingVideo = true;
    });
    if (mediaInfo != null) {
      splitVideo(mediaInfo.file!);
    } else {
      print('No Video selected.');
    }
    setState(() {
      splittingVideo = false;
    });
  }

  void splitVideo(File _video) async {
    print(_video.path);
    String appDocPath = (await getApplicationDocumentsDirectory()).path;
    DateTime.now().millisecondsSinceEpoch.toString();
    double frameLength = 5; //Default should be 120s

    final FlutterFFprobe flutterFFprobe = FlutterFFprobe();
    Map<dynamic, dynamic> videometadata =
        (await flutterFFprobe.getMediaInformation(_video.path))
            .getMediaProperties()!;
    double duration = double.parse(videometadata["duration"]);
    print("duration: $duration");
    print("format: ${formatTime(duration.toInt())}");

    for (double i = 0; i < duration - frameLength; i += frameLength) {
      final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();
      String videoPath = appDocPath +"/"+
          DateTime.now().millisecondsSinceEpoch.toString() +"-"+
          i.toString() +
          ".mp4";
      print(videoPath);
      int rc = await _flutterFFmpeg
          .execute(
              "-ss ${formatTime(i.toInt())} -i \"${_video.path}\" -to ${formatTime((i + frameLength).toInt())} -c copy $videoPath"
      );
      print("FFmpeg process for executionId  exited with rc $rc");
      if (rc == 0) {
        setState(() {
          _videoes.add(File(videoPath));
        });
      }
    }

    final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();
    String videoPath = appDocPath +"/"+
        DateTime.now().millisecondsSinceEpoch.toString() +
        ".mp4";
    print(videoPath);
    int rc = await _flutterFFmpeg
        .execute(
        "-ss ${formatTime((duration - (duration%frameLength)).toInt())} -i \"${_video.path}\" -to ${formatTime((duration).toInt())} -c copy $videoPath"
    );
    print("FFmpeg process for executionId  exited with rc $rc");
    if (rc == 0) {
      setState(() {
        _videoes.add(File(videoPath));
      });
    }
  }

  deleteImage(File img, {bool isVideo = false}) {
    setState(() {
      if (isVideo) {
        _videoes.remove(img);
      } else {
        _images.remove(img);
      }
    });
  }

  Future<bool> _getKey(BuildContext context, {bool video = false}) async {
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
                    if (video)
                      getVideo(false);
                    else
                      getImage(false);
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
        title: Text("Share anomalies' location"),
      ),
      body: SafeArea(
        child: Container(
          constraints: BoxConstraints.expand(),
          decoration: BoxDecoration(
              image: DecorationImage(
            image: AssetImage("assets/background_road.png"),
            fit: BoxFit.cover,
          )),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 100,
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: InkWell(
                          onTap: () {
                            _getKey(context);
                          },
                          child: Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.withOpacity(0.8),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image,
                                  color: Colors.white,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 5.0),
                                  child: Text(
                                    "Image",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Image.asset("assets/taking_picture.png"),
                      flex: 1,
                    )
                  ],
                ),
                (_images.length == 0)
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 100.0),
                        child: Center(
                          child: Text(
                            "Take image of anomalies to share",
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 20,
                              shadows: <Shadow>[
                                Shadow(
                                  offset: Offset(0.0, 0.0),
                                  blurRadius: 3.0,
                                  color: Color.fromARGB(255, 0, 0, 0),
                                ),
                                Shadow(
                                  offset: Offset(0.0, 0.0),
                                  blurRadius: 8.0,
                                  color: Color.fromARGB(125, 0, 0, 255),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                Row(
                  children: [
                    Expanded(
                      child: Image.asset("assets/video_taking.png"),
                      flex: 1,
                    ),
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: InkWell(
                          onTap: () {
                            _getKey(context, video: true);
                          },
                          child: Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.withOpacity(0.8),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.videocam,
                                  color: Colors.white,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 5.0),
                                  child: Text(
                                    "Record",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                _videoes.isEmpty
                    ? Center(
                        child: Text(
                          "Capture video of anomalies to share",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 20,
                            shadows: <Shadow>[
                              Shadow(
                                offset: Offset(0.0, 0.0),
                                blurRadius: 3.0,
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                              Shadow(
                                offset: Offset(0.0, 0.0),
                                blurRadius: 8.0,
                                color: Color.fromARGB(125, 0, 0, 255),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (var v in _videoes)
                            UploadIndividualVideo(
                              imageFile: v,
                              delete: deleteImage,
                              url: url,
                              path: path,
                              // processedVideoUrl: widget.processedVideoUrl,
                            ),
                        ],
                      ),
                VideoCompress.isCompressing || splittingVideo
                    ? Center(
                        child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            Text("Compressing/Processing the video",style: TextStyle(color: Colors.white),),
                          ],
                        ),
                      ))
                    : Container(),
                SizedBox(
                  height: 100,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String formatTime(int n) {
  String str = "";
  str += (n ~/ 3600).toString().padLeft(2, "0");
  n %= 3600;
  str += (":" + (n ~/ 60).toString().padLeft(2, "0"));
  n %= 60;
  str += (":" + (n).toString().padLeft(2, "0"));

  return str;
}
