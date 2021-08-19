import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:chewie/chewie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'AnnomalyLocationsServices.dart';

class UploadIndividualVideo extends StatefulWidget {
  final File imageFile;
  final Function delete;
  final String url;
  final String processedVideoUrl;
  final Map<int, LatLng> path;
  UploadIndividualVideo(
      {required this.imageFile,
      required this.delete,
      this.url = "https://19495e184dba.ngrok.io/predict",
      required this.processedVideoUrl,
      required this.path});

  @override
  _UploadIndividualVideoState createState() => _UploadIndividualVideoState();
}

class _UploadIndividualVideoState extends State<UploadIndividualVideo> {
  bool _error = false;
  bool _uploadComplete = false;
  bool _uploadingNow = false;
  double _uploadSize = 0;
  String downloadUrl = "";
  VideoPlayerController? controller;
  bool processedInBackEnd = false;
  bool isProcessing = false;
  var processedData;
  File? processedImage;
  int contentLength = 0;
  String message = "";
  String processedFileName = "";

  @override
  void initState(){
    super.initState();
    controller = VideoPlayerController.file(widget.imageFile);
    controller?.initialize();
    processedImage = null;
    setProcessedFileName();
  }

  void setProcessedFileName()async{
    var filename = DateTime.now().microsecondsSinceEpoch.toString() + ".mp4";

    String dir = (await getApplicationDocumentsDirectory()).path;
    setState(() {
      processedFileName = '$dir/$filename';
    });
  }

  Future<void> handleUploadTask(File largeFile) async {
    await _uploadToFirebase(largeFile);
    setState(() {
      isProcessing = true;
    });
    var response = await http.post(Uri.parse(this.widget.url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"file": downloadUrl, "type": "video"}));
    setState(() {
      isProcessing = false;
    });
    if (response.statusCode == 200) {
      var body = jsonDecode(response.body);
      print("Processed video");
      print(body);
      setState(() {
        message = body.toString();
      });
      await firebase_storage.FirebaseStorage.instance
          .refFromURL(downloadUrl)
          .delete();
      this.setState(() {
        processedInBackEnd = true;
        downloadUrl = body["url"] as String;
        processedData = body;
      });
      updateAnnomalyLocations(
          widget.path,
          processedData,
          widget.imageFile.lastModifiedSync().millisecondsSinceEpoch -
              (controller!.value.duration.inMilliseconds),
          downloadUrl
      );
    } else {
      print("Backend processing error occured");
      showDialog<String>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Error'),
          content: Text("Backend processing error occurred, please retry.\n" + response.body),
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

  Future<String> getFileSize(File file, int decimals) async {
    int bytes = await file.length();
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) +
        ' ' +
        suffixes[i];
  }

  Future<File> _loadVideo() async {
    if(processedImage != null) return processedImage!;
    var httpClient = new HttpClient();

    File file = new File(processedFileName);

    print(processedFileName);
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
    print("Completed downloading");
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(10),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border:
              Border.all(color: Color.fromRGBO(223, 225, 229, 1.0), width: 1)),
      child: Column(
        children: [
          processedInBackEnd
              ? Row(
            children: [
              ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlayVideo(
                          videoPlayerController:
                          VideoPlayerController.network(downloadUrl),
                          looping: true,
                          autoplay: true,
                        ),
                      ),
                    );
                  },
                  child: Text("Play")),
              contentLength == 0
                  ? Container()
                  : Text("Processed Video: " +
                  (contentLength / 1048576)
                      .toStringAsPrecision(6) +
                  " MB"),
            ],
          )
          // FutureBuilder(
          //         future: _loadVideo(),
          //         builder: (ctx, snapshot) {
          //           if (snapshot.connectionState == ConnectionState.done) {
          //             // If we got an error
          //             if (snapshot.hasError) {
          //               return Center(
          //                 child: Text(
          //                   '${snapshot.error} occured',
          //                   style: TextStyle(fontSize: 18),
          //                 ),
          //               );
          //
          //               // if we got our data
          //             } else if (snapshot.hasData) {
          //               // Extracting data from snapshot object
          //               final data = snapshot.data as File;
          //               return Row(
          //                 children: [
          //                   ElevatedButton(
          //                       onPressed: () {
          //                         Navigator.push(
          //                           context,
          //                           MaterialPageRoute(
          //                             builder: (context) => PlayVideo(
          //                               videoPlayerController:
          //                                   VideoPlayerController.file(data),
          //                               looping: true,
          //                               autoplay: true,
          //                             ),
          //                           ),
          //                         );
          //                       },
          //                       child: Text("Play")),
          //                   contentLength == 0
          //                       ? Container()
          //                       : Text("Processed Video: " +
          //                           (contentLength / 1048576)
          //                               .toStringAsPrecision(6) +
          //                           " MB"),
          //                 ],
          //               );
          //             }
          //           }
          //
          //           // Displaying LoadingSpinner to indicate waiting state
          //           return Center(
          //             child: CircularProgressIndicator(),
          //           );
          //         },
          //       )
              : FittedBox(
                  child: FutureBuilder(
                    future: getFileSize(widget.imageFile, 2),
                    builder: (ctx, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              '${snapshot.error} occured',
                              style: TextStyle(fontSize: 18),
                            ),
                          );

                          // if we got our data
                        } else if (snapshot.hasData) {
                          final data = snapshot.data as String;
                          return Row(
                            children: [
                              ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PlayVideo(
                                          videoPlayerController:
                                              VideoPlayerController.file(
                                                  widget.imageFile),
                                          looping: true,
                                          autoplay: true,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text("Play")),
                              Text("Captured Video: $data"),
                            ],
                          );
                        }
                      }

                      // Displaying LoadingSpinner to indicate waiting state
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  ),
                ),
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
                            await handleUploadTask(this.widget.imageFile);
                          } catch (error) {
                            showDialog<String>(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                title: const Text('Upload error'),
                                content: Text(error.toString()),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, 'OK'),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
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
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all<Color>(Colors.red),
                  ),
                  onPressed: () {
                    this.widget.delete(this.widget.imageFile, isVideo: true);
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
          if (_error)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Failed to Upload :(\nTry again!",
              ),
            ),
          if (isProcessing) Text("Please wait while processing the video...."),
          Container(
            child: Text(message),
          )
        ],
      ),
    );
  }
}

class PlayVideo extends StatefulWidget {
  final VideoPlayerController videoPlayerController;
  final bool looping;
  final bool autoplay;

  const PlayVideo(
      {required this.videoPlayerController,
      required this.looping,
      required this.autoplay,
      Key? key})
      : super(key: key);

  @override
  _PlayVideoState createState() => _PlayVideoState();
}

class _PlayVideoState extends State<PlayVideo> {
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _chewieController = ChewieController(
      videoPlayerController: widget.videoPlayerController,
      aspectRatio: 5 / 8,
      autoInitialize: true,
      autoPlay: widget.autoplay,
      looping: widget.looping,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            errorMessage,
            style: TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    _chewieController?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Scaffold(
        appBar: AppBar(
          title: Text("Play Video"),
        ),
        body: Chewie(
          controller: _chewieController,
        ),
      ),
    );
  }
}



