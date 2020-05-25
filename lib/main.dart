import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_openvidu_demo/call_sample.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(MaterialApp(home: MyHome()));

class MyHome extends StatefulWidget {
  @override
  _MyHomeState createState() => new _MyHomeState();
}

class _MyHomeState extends State<MyHome> {

  bool isOnline = false;
  TextEditingController _textSessionController;
  TextEditingController _textUserNameController;
  TextEditingController _textUrlController;
  TextEditingController _textSecretController;
  TextEditingController _textPortController;
  TextEditingController _textIceServersController;

  @override
  void initState() {
    super.initState();

    _textSessionController    = TextEditingController(text: 'Session-flutter-test-${Random().nextInt(1000)}');
    _textUserNameController   = TextEditingController(text: 'FlutterUser${Random().nextInt(1000)}');
    _textUrlController        = TextEditingController(text: 'demos.openvidu.io');
    _textSecretController     = TextEditingController(text: 'MY_SECRET');
    _textPortController       = TextEditingController(text: '443');
    _textIceServersController = TextEditingController(text: 'stun.l.google.com:19302');

    _loadSharedPref();
    _liveConn();
  }

  Future<void> _loadSharedPref() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _textUrlController.text        = prefs.getString('textUrl')        ?? _textUrlController.text;
    _textSecretController.text     = prefs.getString('textSecret')     ?? _textSecretController.text;
    _textPortController.text       = prefs.getString('textPort')       ?? _textPortController.text;
    _textIceServersController.text = prefs.getString('textIceServers') ?? _textIceServersController.text;
    print('Loaded user inputs value.');
  }

  Future<void> _saveSharedPref() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('textUrl', _textUrlController.text);
    await prefs.setString('textSecret', _textSecretController.text);
    await prefs.setString('textPort', _textPortController.text);
    await prefs.setString('textIceServers', _textIceServersController.text);
    print('Saved user inputs values.'); 
  }

  Future<void> _liveConn() async{
    await _checkOnline();
    Timer.periodic(Duration(seconds: 5), (timer) async{
      await _checkOnline();
    });
  }
  Future<void> _checkOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        if (!isOnline) {
          isOnline = true;
          setState(() {});
          print('Online..');
        }
      }
    } on SocketException catch (_) {
      if (isOnline) {
        isOnline = false;
        setState(() {});
        print('..Offline');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: const Text('Flutter openVidu demo'),
          actions: <Widget>[
            Row(children: <Widget>[
              isOnline ? Image(image: AssetImage('assets/openvidu_logo.png'),fit: BoxFit.fill, width: 35,) :
              Image(image: AssetImage('assets/offline_icon.png'),fit: BoxFit.fill, width: 35,),
            ]),
          ]
        ),
        drawer: Drawer(
          child: ListView(
            children: <Widget>[
              ListTile(
                leading: CircleAvatar(backgroundImage:  AssetImage('assets/openvidu_logo.png')),
                title: Text("Flutter openVidu demo"),
                subtitle: Text("v 1.0.0"),
              ),
              ListTile(leading: Icon(Icons.home), title: Text("Home"),onTap:(){Navigator.of(context).pop();}),
              InkWell(
                  child: new ListTile(leading: Icon(Icons.insert_link), title: Text("GitHub")),
                  onTap: () => launch('https://github.com/cyb3rcod3/flutter-openvidu-demo')
              ),
              InkWell(
                  child: new ListTile(leading: Icon(Icons.insert_link), title: Text("openVidu")),
                  onTap: () => launch('https://openvidu.io')
              ),
              
            ],
          )
        ),
        body: Container(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  SizedBox(height: 10),
                  TextField(
                    controller: _textSessionController,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.all(5),
                      border: OutlineInputBorder(),
                      labelText: 'Session room name',
                      hintText: 'Enter session room name'
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _textUserNameController,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.all(5),
                      border: OutlineInputBorder(),
                      labelText: 'Session username',
                      hintText: 'Enter username'
                    ),
                  ),
                  SizedBox(height: 40),
                  TextField(
                    controller: _textUrlController,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.all(5),
                      border: OutlineInputBorder(),
                      labelText: 'openVidu server url',
                      hintText: 'Enter openVidu server url'
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _textPortController,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.all(5),
                      border: OutlineInputBorder(),
                      labelText: 'openVidu server port',
                      hintText: 'Enter openVidu server port'
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _textSecretController,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.all(5),
                      border: OutlineInputBorder(),
                      labelText: 'openVidu server secret',
                      hintText: 'Enter openVidu server secret'
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _textIceServersController,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.all(5),
                      border: OutlineInputBorder(),
                      labelText: 'Ice server',
                      hintText: 'Enter ice server url'
                    ),
                  ),
                  SizedBox(
                    height: 30,
                  ),
                  FlatButton(
                    child: Text(isOnline ? 'JoinRoom' : '   Offline  ', style: TextStyle(fontSize: 20.0),),
                    textColor: Colors.white,
                    padding: EdgeInsets.all(15.0),
                    color: Colors.green[400],
                    disabledColor: Colors.grey,
                    onPressed: isOnline ? () => 
                    Navigator.push(context, MaterialPageRoute(builder: (context) {
                      _saveSharedPref();
                      return CallSampleWidget( server: '${_textUrlController.text}:${_textPortController.text}', 
                                      sessionName: _textSessionController.text, 
                                         userName: _textUserNameController.text, 
                                           secret: _textSecretController.text, 
                                        iceServer: _textIceServersController.text );
                      })
                    ) : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}
