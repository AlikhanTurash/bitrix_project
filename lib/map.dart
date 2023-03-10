import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_app/data_service.dart';
import 'package:google_maps_app/location_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import './constants.dart';
import 'match_class.dart';
import 'model.dart';

class MapSample extends StatefulWidget {
  @override
  State<MapSample> createState() => MapSampleState();
}

class MapSampleState extends State<MapSample> {
  //контроллер Гугл Карт
  Completer<GoogleMapController> _controller = Completer();

  //контроллеры текстфилдов
  TextEditingController _originController = TextEditingController();
  TextEditingController _destinationController = TextEditingController();

  //коллекции маркеров и полилайнов
  Set<Marker> _markers = Set<Marker>();
  Set<Polyline> _polylines = Set<Polyline>();

  //ID для полилайнов
  int _polylineIdCounter = 1;

  //Информация о пользователях
  late Model? _userModel;

  //Users
  var usersMap = {'user': ''};

  //Позиция камеры на москву при иницализации карты
  static const CameraPosition _moscow = CameraPosition(
    target: LatLng(55.751244, 37.618423),
    zoom: 8,
  );

  //List of matches
  List<MatchItem> Matches = [];

  @override
  void initState() {
    super.initState();
    _getData();
  }

  void _getData() async {
    _userModel = await DataService().getData();
    _setUserMarkers();
  }

  void _setUserMarkers() async {
    int? count = _userModel?.result.length;
    List<LatLng> sellerLatLng = [];
    List<LatLng> buyerLatLng = [];

    for (int i = 0; i < count!; i++) {
      String? coordinates = _userModel?.result[i].ufCrm1671547810826;
      String? title = _userModel?.result[i].title;
      var a = (coordinates?.split('|')[1])?.split(';');
      LatLng latLng = LatLng(double.parse(a![0]), double.parse(a[1]));
      _setMarker(latLng, title, '');
      if (title!.contains('Продавец')) {
        sellerLatLng.add(latLng);
        _setMarker(latLng, title, 'Продавец');
      } else if (title.contains('Покупатель')) {
        buyerLatLng.add(latLng);
        _setMarker(latLng, title, 'Покупатель');
      }
    }
    List<double> pathLat = [];
    List<double> pathLng = [];
    List<int> lengthMetres = [];
    for (int i = 0; i < sellerLatLng.length; i++) {
      _drawRoute(sellerLatLng[i], buyerLatLng[0]);
      pathLat.add(sellerLatLng[i].latitude);
      pathLng.add(sellerLatLng[i].longitude);
      String origin = (sellerLatLng[i].latitude.toString() +
          "," +
          sellerLatLng[i].longitude.toString());
      String destination = (buyerLatLng[0].latitude.toString() +
          "," +
          buyerLatLng[0].longitude.toString());
      lengthMetres.add(await _getMatchDirectionLength(origin, destination));
      String? sellerTitle = _userModel?.result[i].title;
      String? buyerTitle = _userModel?.result[2].title;
      int quantity = 1;
      double profit;
      double deliveryCost = 1000 + lengthMetres[i] / 10;
      double priceBuyer = double.parse(_userModel!.result[2].opportunity);
      double priceSeller = double.parse(_userModel!.result[i].opportunity);
      profit = priceBuyer * quantity - priceSeller * quantity - deliveryCost;
      String snippet = 'Доход: ' + profit.toString() + 'руб.';
      if (sellerTitle!.contains('Продавец')) {
        _setMarker(sellerLatLng[i], sellerTitle, snippet);
      } else if (sellerTitle.contains('Покупатель')) {
        _setMarker(sellerLatLng[i], sellerTitle, snippet);
      }
      print(MatchItem(sellerTitle, buyerTitle!, profit, priceSeller, priceBuyer,
          deliveryCost));
      Matches.add(MatchItem(sellerTitle, buyerTitle!, profit, priceSeller,
          priceBuyer, deliveryCost));
    }
  }

  void _drawRoute(LatLng a, LatLng b) async {
    String origin = (a.latitude.toString() + "," + a.longitude.toString());
    String destination = (b.latitude.toString() + "," + b.longitude.toString());
    print(origin);
    print(destination);
    var directions1 = await LocationService()
        .getDirections(origin.toString(), destination.toString(), 'driving');
    _setPolyline(directions1['polyline_decoded'], Colors.pinkAccent);
  }

  Future<int> _getMatchDirectionLength(
      String origin, String destination) async {
    int length = 0;
    var a = await LocationService().getDirectionLength(origin, destination);
    length = a['length'];
    print(length);
    return length;
  }

  // void _updateMarker(String? title, String? snippet) {
  //   setState(
  //     () {
  //       _markers.add(
  //         Marker(
  //             markerId: MarkerId(title!),
  //             infoWindow: InfoWindow(title: title, snippet: snippet)),
  //       );
  //     },
  //   );
  // }

  //Функция установки маркера на карту
  void _setMarker(LatLng point, String? title, String? snippet) {
    setState(
      () {
        _markers.add(
          Marker(
              markerId: MarkerId(title!),
              position: point,
              infoWindow: InfoWindow(title: title, snippet: snippet)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SlidingUpPanel(
          body: GoogleMap(
            zoomControlsEnabled: false,
            polylines: _polylines,
            mapType: MapType.normal,
            initialCameraPosition: _moscow,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            markers: _markers,
          ),
          panel: _userModel == null || _userModel!.result.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : Padding(
                  padding: EdgeInsets.all(15),
                  child: Column(
                    children: [
                      Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 8,
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.arrow_drop_down_circle),
                              title: Text(
                                  Matches[0].seller + '—' + Matches[0].buyer),
                              subtitle: Text(
                                Matches[0].profit.toString() + 'руб.',
                                style: TextStyle(
                                    color: Colors.black.withOpacity(0.6)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                    'Продавец: ' + Matches[0].seller,
                                    style: TextStyle(
                                        color: Colors.black.withOpacity(0.6)),
                                  ),
                                  Text(
                                    'Покупатель: ' + Matches[0].buyer,
                                    style: TextStyle(
                                        color: Colors.black.withOpacity(0.6)),
                                  ),
                                  Text(
                                    'Доход: ' +
                                        Matches[0].profit.toString() +
                                        'руб.',
                                    style: TextStyle(
                                        color: Colors.black.withOpacity(0.6)),
                                  ),
                                  Text(
                                    'Цена продавца: ' +
                                        Matches[0].sellerPrice.toString() +
                                        'руб.',
                                    style: TextStyle(
                                        color: Colors.black.withOpacity(0.6)),
                                  ),
                                  Text(
                                    'Цена покупателя: ' +
                                        Matches[0].buyerPrice.toString() +
                                        'руб.',
                                    style: TextStyle(
                                        color: Colors.black.withOpacity(0.6)),
                                  ),
                                  Text(
                                    'Доставка: ' +
                                        Matches[0].delivery.toString() +
                                        'руб.',
                                    style: TextStyle(
                                        color: Colors.black.withOpacity(0.6)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 8,
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.arrow_drop_down_circle),
                              title: Text(
                                  Matches[1].seller + '—' + Matches[1].buyer),
                              subtitle: Text(
                                Matches[1].profit.toString() + 'руб.',
                                style: TextStyle(
                                    color: Colors.black.withOpacity(0.6)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                    'Продавец: ' + Matches[1].seller,
                                    style: TextStyle(
                                        color: Colors.black.withOpacity(0.6)),
                                  ),
                                  Text(
                                    'Покупатель: ' + Matches[1].buyer,
                                    style: TextStyle(
                                        color: Colors.black.withOpacity(0.6)),
                                  ),
                                  Text(
                                    'Доход: ' +
                                        Matches[1].profit.toString() +
                                        'руб.',
                                    style: TextStyle(
                                        color: Colors.black.withOpacity(0.6)),
                                  ),
                                  Text(
                                    'Цена продавца: ' +
                                        Matches[1].sellerPrice.toString() +
                                        'руб.',
                                    style: TextStyle(
                                        color: Colors.black.withOpacity(0.6)),
                                  ),
                                  Text(
                                    'Цена покупателя: ' +
                                        Matches[1].buyerPrice.toString() +
                                        'руб.',
                                    style: TextStyle(
                                        color: Colors.black.withOpacity(0.6)),
                                  ),
                                  Text(
                                    'Доставка: ' +
                                        Matches[1].delivery.toString() +
                                        'руб.',
                                    style: TextStyle(
                                        color: Colors.black.withOpacity(0.6)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
    );
  }

  //Функция по поиску ближайшего стопа
  //На выходе индекс ближайшего стопа
  Future<int> _findClosestStop(String point) async {
    var res = [0, 0, 0, 0, 0, 0];
    for (int i = 0; i < 6; i++) {
      var a = await LocationService().getDirectionLength(
        point,
        bicycleStops[i].position.latitude.toString() +
            ',' +
            bicycleStops[i].position.longitude.toString(),
      );
      res[i] = a['length'];
    }

    int min = res.reduce((curr, next) => curr > next ? curr : next);

    return res.indexOf(min);
  }

  //Функция отрисовки Полилайнов
  void _setPolyline(List<PointLatLng> points, Color color) {
    final String polylineIdVal = 'polyline_$_polylineIdCounter';
    _polylineIdCounter++;
    _polylines.add(
      Polyline(
          polylineId: PolylineId(polylineIdVal),
          width: 2,
          color: color,
          points: points
              .map(
                (point) => LatLng(point.latitude, point.longitude),
              )
              .toList()),
    );
  }

  //Функция перемещения камеры с анимацией
  Future<void> _goToPlace(double lat, double lng, Map<String, dynamic> boundsNe,
      Map<String, dynamic> boundsSw) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 12),
      ),
    );

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
          LatLngBounds(
              southwest: LatLng(boundsSw['lat'], boundsSw['lng']),
              northeast: LatLng(boundsNe['lat'], boundsNe['lng'])),
          25),
    );
    // _setMarker(LatLng(lat, lng));
  }
}
