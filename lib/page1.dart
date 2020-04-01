import 'package:flutter/material.dart';

import 'shop/shop_scroll_controller.dart';
import 'shop/shop_scroll_coordinator.dart';

class Page1 extends StatefulWidget {
  final ShopScrollCoordinator shopCoordinator;

  const Page1({@required this.shopCoordinator, Key key}) : super(key: key);

  @override
  _Page1State createState() => _Page1State();
}

class _Page1State extends State<Page1> {
  ShopScrollCoordinator _shopCoordinator;
  ShopScrollController _listScrollController1;
  ShopScrollController _listScrollController2;

  @override
  void initState() {
    _shopCoordinator = widget.shopCoordinator;
    _listScrollController1 = _shopCoordinator.newChildScrollController();
    _listScrollController2 = _shopCoordinator.newChildScrollController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(0),
            physics: AlwaysScrollableScrollPhysics(),
            controller: _listScrollController1,
            itemExtent: 50.0,
            itemCount: 20,
            itemBuilder: (context, index) => Container(
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(5.0),
                color: index % 2 == 0 ? Colors.cyan : Colors.deepOrange,
                child: Center(child: Text(index.toString())),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: ListView.builder(
            padding: EdgeInsets.all(0),
            physics: AlwaysScrollableScrollPhysics(),
            controller: _listScrollController2,
            itemExtent: 200.0,
            itemCount: 30,
            itemBuilder: (context, index) => Container(
              padding: EdgeInsets.symmetric(horizontal: 1),
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(5.0),
                color: index % 2 == 0 ? Colors.cyan : Colors.deepOrange,
                child: Center(child: Text(index.toString())),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _listScrollController1?.dispose();
    _listScrollController2?.dispose();
    _listScrollController1 = _listScrollController2 = null;
    super.dispose();
  }
}
