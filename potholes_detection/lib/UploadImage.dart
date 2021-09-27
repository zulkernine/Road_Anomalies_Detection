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
  final List<Map<String, String>> videoes;
  final String processedVideoUrl;
  final String url;
  final Map<int, LatLng> path;
  final Function updateServerUrl;

  UploadImage(
      {required this.images,
      required this.url,
      required this.videoes,
      required this.path,
      required this.updateServerUrl,
      required this.processedVideoUrl});

  @override
  _UploadImageState createState() => _UploadImageState();
}

class _UploadImageState extends State<UploadImage> {
  List<File> _images = [];
  // File? _videoes = null;
  // List<File> _videoes = [];
  List<Map<String, String>> _videoes =
      []; // {"filePath":"", "creationTime":"ISO_FORMATE_Date"}
  String url = "";
  bool recordingNow = false;
  Map<int, LatLng> path = {};
  bool splittingVideo = false;
  int currentlyUploadingVideoIndex = -1;
  int recordStartTime = 0;

  LatLng? currentLoc;

  @override
  void initState() {
    super.initState();
    _images = this.widget.images;
    _videoes = widget.videoes;
    url = widget.url;
    path = widget.path;
    Location().onLocationChanged.listen((LocationData currentLocation) {
      print(recordingNow);
      if (recordingNow) {
        path[DateTime.now().millisecondsSinceEpoch] =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);
        // setState(() {
        //   currentLoc = LatLng(currentLocation.latitude!, currentLocation.longitude!);
        // });
      }
    });
  }

  Future getImage(bool gallery) async {
    ImagePicker picker = ImagePicker();
    XFile? pickedFile;
    // Let user select photo from gallery
    if (gallery) {
      pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxHeight: 1024,
          maxWidth: 1024,
          imageQuality: 60);
    }
    // Otherwise open camera to get new photo
    else {
      pickedFile =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
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
    XFile? pickedVideoFile;
    setState(() {
      splittingVideo = true;
      recordingNow = true;
      recordStartTime = DateTime.now().millisecondsSinceEpoch;
    });
    // Let user select photo from gallery - DON'T, take live camera and location :-(
    if (gallery) {
      pickedVideoFile = await picker.pickVideo(
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
      pickedVideoFile = await picker.pickVideo(
        source: ImageSource.camera,
      );

      loc = await Location().getLocation();
      setState(() {
        recordingNow = false;
        path[DateTime.now().millisecondsSinceEpoch] =
            LatLng(loc.latitude!, loc.longitude!);
      });
      // print(File(pickedVideoFile!.path).lastModifiedSync());
    }
    MediaInfo? mediaInfo;
    if (pickedVideoFile != null) {
      mediaInfo = await VideoCompress.compressVideo(
        pickedVideoFile.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false, // It's false by default
        includeAudio: false,
        frameRate: 30,
      );
    }

    if (mediaInfo != null) {
      await splitVideo(mediaInfo.file!);
    } else {
      print('No Video selected.');
    }
    setState(() {
      splittingVideo = false;
      recordingNow = false;
    });

    print("main() videoes length: ${widget.videoes.length}");
  }

  Future splitVideo(File _video) async {
    print(_video.path);
    String appDocPath = (await getApplicationDocumentsDirectory()).path;
    double frameLength = 120; //Default should be 120s

    final FlutterFFprobe flutterFFprobe = FlutterFFprobe();
    Map<dynamic, dynamic> videometadata =
        (await flutterFFprobe.getMediaInformation(_video.path))
            .getMediaProperties()!;
    double duration = double.parse(videometadata["duration"]);
    print("duration: $duration");
    print("format: ${formatTime(duration.toInt())}");
    print(videometadata);
    // int creationTime = DateTime.parse(videometadata["tags"]["creation_time"])
    //     .millisecondsSinceEpoch;
    int creationTime = recordStartTime;

    for (double i = 0; i < duration - frameLength; i += frameLength) {
      final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();
      String videoPath = appDocPath +
          "/" +
          DateTime.now().millisecondsSinceEpoch.toString() +
          "-" +
          i.toString() +
          ".mp4";
      print(videoPath);
      int rc = await _flutterFFmpeg.execute(
          "-ss ${formatTime(i.toInt())} -i \"${_video.path}\" -t ${formatTime((frameLength).toInt())} -c copy $videoPath");
      print("FFmpeg process for executionId  exited with rc $rc");
      if (rc == 0) {
        setState(() {
          _videoes.add({
            "filePath": videoPath,
            "creationTime": (creationTime + i.toInt()).toString()
          });
        });
      }
    }

    final FlutterFFmpeg _flutterFFmpeg = new FlutterFFmpeg();
    String videoPath = appDocPath +
        "/" +
        DateTime.now().millisecondsSinceEpoch.toString() +
        ".mp4";
    print(videoPath);
    int rc = await _flutterFFmpeg.execute(
        "-ss ${formatTime((duration - (duration % frameLength)).toInt())} -i \"${_video.path}\" -t ${formatTime(((duration % frameLength)).toInt())} -c copy $videoPath");
    print("FFmpeg process for executionId  exited with rc $rc");
    if (rc == 0) {
      setState(() {
        _videoes.add({
          "filePath": videoPath,
          "creationTime":
              (creationTime + (duration - (duration % frameLength)).toInt())
                  .toString()
        });
      });
    }
  }

  deleteImage(File img, {bool isVideo = false}) {
    setState(() {
      if (isVideo) {
        _videoes
            .removeWhere((Map<String, String> e) => e["filePath"] == img.path);
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
                    print(url);
                    widget.updateServerUrl(url);
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

  void uploadNextVideo(){
    setState(() {
      if(_videoes.length > currentlyUploadingVideoIndex+1)
        ++currentlyUploadingVideoIndex;
      else
        currentlyUploadingVideoIndex = -1;
    });
  }

  void uploadAllVideo(){
    setState(() {
      currentlyUploadingVideoIndex = 0;
    });
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
              gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [Colors.black12, Colors.grey, Colors.white]),
              // color: Colors.grey.shade300,
              image: DecorationImage(
                image: AssetImage("assets/background3.png"),
                fit: BoxFit.fitHeight,
              )),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 40,
                  child: currentLoc!=null ? Text(currentLoc.toString(),style: TextStyle(color: Colors.white),): Container(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () {
                        _getKey(context);
                      },
                      child: Container(
                        height: 120,
                        width: 160,
                        margin: EdgeInsets.only(right: 15),
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.lightBlue.withOpacity(0.6),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 5.0),
                                  child: Text(
                                    "Capture",
                                    style: TextStyle(
                                        color: Colors.black, fontSize: 25),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 5.0, top: 5),
                              child: Text(
                                "Upload anomaly image from camera",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                (_images.length == 0)
                    ? Container(
                        height: 250,
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
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        _getKey(context, video: true);
                      },
                      child: Container(
                        height: 120,
                        width: 160,
                        margin: EdgeInsets.only(left: 15),
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.lightBlue.withOpacity(0.8),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                  ),
                                  child: Icon(
                                    Icons.videocam,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 5.0),
                                  child: Text(
                                    "Record",
                                    style: TextStyle(
                                        color: Colors.black, fontSize: 25),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 5.0, top: 5),
                              child: Text(
                                "Upload continuous video of road",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                _videoes.isEmpty
                    ? Container()
                    : Column(
                        children: [
                          ElevatedButton(onPressed: (){uploadAllVideo();}, child: Text("Upload All Video")),
                          for (int i=0;i<_videoes.length;i++) // var v in _videoes)
                            UploadIndividualVideo(
                              imageFile: File(_videoes[i]["filePath"]!),
                              delete: deleteImage,
                              url: url,
                              path: path,
                              startTime: int.parse(_videoes[i]["creationTime"]!),
                              uploadImmedeately: currentlyUploadingVideoIndex==i,
                              uploadNext: uploadNextVideo,
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
                            Text(
                              "Compressing/Processing the video",
                              style: TextStyle(color: Colors.white),
                            ),
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
