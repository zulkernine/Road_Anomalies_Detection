import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:potholes_detection/main.dart';

class Anomalies {
  Set<LatLng> wet_potholes = <LatLng>{};
  Set<LatLng> dry_potholes = <LatLng>{};
  Set<LatLng> manholes = <LatLng>{};
  Set<LatLng> speed_breaker = <LatLng>{};
  Set<LatLng> uneven_surface = <LatLng>{};

  Anomalies();

  Anomalies.fromJson(Map<String, dynamic> data) {

    wet_potholes.addAll([
      for (List l in jsonDecode(data["wet_potholes"])) LatLng(l.first, l.last)
    ]);
    dry_potholes.addAll([
      for (List l in jsonDecode(data["dry_potholes"])) LatLng(l.first, l.last)
    ]);
    manholes.addAll(
        [for (List l in jsonDecode(data["manholes"])) LatLng(l.first, l.last)]);
    speed_breaker.addAll([
      for (List l in jsonDecode(data["speed_breaker"])) LatLng(l.first, l.last)
    ]);
    uneven_surface.addAll([
      for (List l in jsonDecode(data["uneven_surface"])) LatLng(l.first, l.last)
    ]);
  }

  Map<String, dynamic> toJson() {
    return {
      "wet_potholes": jsonEncode(wet_potholes.toList()),
      "dry_potholes": jsonEncode(dry_potholes.toList()),
      "manholes": jsonEncode(manholes.toList()),
      "speed_breaker": jsonEncode(speed_breaker.toList()),
      "uneven_surface": jsonEncode(uneven_surface.toList()),
    };
  }

  void merge(Anomalies anm) {
    this.wet_potholes = this.wet_potholes.union(anm.wet_potholes);
    this.dry_potholes = this.dry_potholes.union(anm.dry_potholes);
    this.manholes = this.manholes.union(anm.manholes);
    this.speed_breaker = this.speed_breaker.union(anm.speed_breaker);
    this.uneven_surface = this.uneven_surface.union(anm.uneven_surface);
  }

}

class Anomaly{
  LatLng position = LatLng(0, 0);
  Set<String> names = Set();
  String sourceUrl = "";
  String sourceType = "image"; // or video

  Anomaly(LatLng pos,Set<String>names,String url, {String type="image"}){
    position = pos;
    this.names.addAll(names);
    sourceUrl = url;
    sourceType = type;
  }

  Map<String, dynamic> toJson(){
    return {
      "position": jsonEncode(position),
      "names": jsonEncode(names.toList()),
      "sourceUrl" : sourceUrl,
      "sourceType" : sourceType
    };
  }

  Anomaly.fromJson(Map<String, dynamic> data){
    var coordinates = jsonDecode(data["position"]);
    position = LatLng(coordinates.first, coordinates.last);
    var types = jsonDecode(data["names"]);
    names.addAll([
      for(var s in types) s.toString()
    ]);

    sourceUrl = data["sourceUrl"].toString();
    sourceType = data["sourceType"].toString();
  }
}


Future<void> updateAnomaly({required LatLng location,required Set<String> anomaliesName,required url}) async {
  if(anomaliesName.isEmpty) return;

  Anomaly anomaly = Anomaly(location, anomaliesName, url);
  print("Updating firestore");
  print(anomaly.toJson());
  CollectionReference ref = FirebaseFirestore.instance
      .collection("road_anomalies2");
  await ref.doc(location.longitude.toString()+location.latitude.toString()).set(
      anomaly.toJson()
  );
  print("Completed updating firestore");

  // FirebaseFirestore.instance.runTransaction((transaction) async {
  //   DocumentSnapshot snapshot = await transaction.get(ref);
  //   anomalies
  //       .merge(Anomalies.fromJson(snapshot.data() as Map<String, dynamic>));
  //   transaction.update(snapshot.reference, anomalies.toJson());
  //
  // });
}

Future<void> updateAnnomalyLocations(Map<int, LatLng> path,var result,int startingTime,String videoUrl)async{
  var lb = result['labels'] as Map;
  Map<LatLng,Anomaly> processedData=Map();
  for(var e in lb.entries){
    if((e.value as List).isNotEmpty){
      LatLng location = path[closestKey(path.keys.toList(), startingTime + (double.parse(e.key as String) * 1000).toInt())]!;
      Anomaly anomaly = Anomaly(location,<String>[ for(var s in e.value ) s.toString() ].toSet(), videoUrl,type: "video");

      if(processedData.containsKey(location)){
        processedData[location]!.names.addAll(anomaly.names);
      }else{
        processedData[location] = anomaly;
      }
    }
  }

  print("Updating firestore");
  for(LatLng l in processedData.keys){
    print(processedData[l]!.toJson());
    CollectionReference ref = FirebaseFirestore.instance
        .collection("road_anomalies2");
    await ref.doc(l.longitude.toString()+l.latitude.toString()).set(
        processedData[l]!.toJson()
    );
  }
  print("Completed updating firestore");
}

//For internal use only
int closestKey(List<int> timestamps, int t){
  int start = 0; int end  = timestamps.length -1; int mid = 0;
  while(start < end){
    mid = (start + end) ~/ 2 ;

    if(timestamps[mid] > t){
      end = mid -1;
    }else{
      start = mid + 1;
    }
  }

  int d1 = t - timestamps[mid],d2 = timestamps[mid+1] - t;
  if(d1 > d2) return timestamps[mid+1];

  return timestamps[mid];
}

