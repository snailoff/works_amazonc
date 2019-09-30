// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:http/http.dart' as http;
import 'package:mysql1/mysql1.dart' as sql;
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
//import 'package:shared_preferences/shared_preferences.dart';

var settings = new sql.ConnectionSettings(
  host: 'jobbot.co.kr',
  port: 3306,
  user: 'amazonc',
  password: 'skantkfkd55',
  db: 'amazonc',
);

//    var abspath = '/Users/snailoff/workspace/flutter/works_amazonc/temp/';
var abspath = '/amazonc_download';
//var abspath = '/amazonc';

void main() {

  // See https://github.com/flutter/flutter/wiki/Desktop-shells#target-platform-override
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

  var workdir = new Directory(abspath);
  if(workdir.existsSync()){
    runApp(new MyApp());

  }else{
    workdir.create().then((_) {
      runApp(new MyApp());
    }).catchError((_){
      runApp(new INeedWorkdir());
    });

  }
}

class INeedWorkdir extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            appBar: AppBar(
              title: Text('amazon crawl'),
            ),
            body: Padding(
              padding: EdgeInsets.all(10.0),
              child: Text("make work directory. 'c:\\amazonc_download'"),
            )
        )
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'amazonc',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          // See https://github.com/flutter/flutter/wiki/Desktop-shells#fonts
          fontFamily: 'Roboto',
        ),
      home: LoginPage(),
      routes: {
        "/login": (_) => new LoginPage(),
        "/home": (_) => new CrawlPage(),
      }
    );
  }
}


class LoginPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _LoginState();
}

class _LoginState extends State<LoginPage> {
  TextEditingController useridInputController;
  TextEditingController passwdInputController;

  final loginFormKey = GlobalKey<FormState>();

  FocusNode focusPasswd;

  void listener(v){
    print(v);

  }

  @override
  void initState() {
    useridInputController = TextEditingController();
//    useridInputController.addListener(listener);
    passwdInputController = TextEditingController();
    focusPasswd = FocusNode();
    super.initState();
  }

  @override
  void dispose() {
    useridInputController.dispose();
    passwdInputController.dispose();
    focusPasswd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
          appBar: AppBar(
            title: Text('amazon crawl'),
          ),
          body: Padding(
              padding: EdgeInsets.all(10.0),
              child:
              Form(key: loginFormKey,
                child: Column(
                      children: <Widget>[
                        TextFormField(
                          decoration: InputDecoration( labelText: 'User ID'),
                          controller: useridInputController,
                          onFieldSubmitted: (term){
                            FocusScope.of(context).requestFocus(focusPasswd);
                          },
                          validator: (value) {
                            if (value.isEmpty) {
                              return 'User ID를 입력해주세요.';
                            }
                            return null;
                          },
                          onTap: () => useridInputController.clear()
                        ),
                      TextFormField(
                        focusNode: focusPasswd,
                        decoration: InputDecoration( labelText: 'PASSWORD'),
                        controller: passwdInputController,
                        obscureText: true,
                        onFieldSubmitted: (term) => loginProcess(context),
                        validator: (value) {
                          if (value.isEmpty) {
                            return 'PASSWORD 를 입력해주세요.';
                          }
                          return null;
                        },
                        onTap: () => passwdInputController.clear()
                      ),
                      RaisedButton(
                        onPressed: () => loginProcess(context),
                        child: Text('login'),
                      ),
                    ],
                  )
                ,)

          )
      ),
    );
  }

  Future loginProcess(context) async {
    if(loginFormKey.currentState.validate() == false) {
      return;
    }

    var isservice = await SessionManager.isService();
    var isvalid = await SessionManager.isValidUser(
        useridInputController != null ? useridInputController.text : '',
        passwdInputController != null ? passwdInputController.text : ''
    );

    if(isservice == false){
      Util.showAlertDialog(context, '서비스가 OFF 상태이므로 로그인 할 수 없습니다');
      return;
    }

    if(isvalid == false){
      Util.showAlertDialog(context, '존재하지 않는 User ID 이거나 Password 가 잘못되었습니다.');
      return;
    }

    await Navigator.pushReplacementNamed(context, '/home');
  }


}



class CrawlPage extends StatefulWidget {
  CrawlPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _CrawlPageState createState() => _CrawlPageState();
}



class _CrawlPageState extends State<CrawlPage> with SingleTickerProviderStateMixin {

  var targetFileName = '<not selected>';
  var targetTotal = 0;
  var targetProgressed = 0;
  var isRetry = true;
  var isServing = true;

  Timer _timer;

  // multiple
  var multiplelist = List<CrawlItem>();
  var filelists = List<File>();
  var targetMultipleSavepath = '';

  // single
  var singlelist = List<CrawlItem>();
  var isEnableAction = true;
  final singleFormKey = GlobalKey<FormState>();
  var targetSingleSavepath = '';
  TextEditingController noInputController;
  TextEditingController urlInputController;
  FocusNode focusSingleUrl;



  @override
  void initState() {
    urlInputController = TextEditingController();
    noInputController = TextEditingController();
    focusSingleUrl = FocusNode();

    refreshTargetList();
    serviceCheck();

    super.initState();
  }

  @override
  void dispose() {
    urlInputController.dispose();
    noInputController.dispose();
    focusSingleUrl.dispose();
    _timer.cancel();
    super.dispose();
  }

  void serviceCheck() {
    _timer = new Timer.periodic(Duration(seconds: 5), (timer) async {
      var isservice = await SessionManager.isService();
      setState(() {
        isServing = isservice;
      });
    });
  }

//  Future<String> getSortingOrder() async {
//    final SharedPreferences prefs = await SharedPreferences.getInstance();
//
//    return prefs.getString('hehe') ?? 'name';
//  }
//
//  /// ----------------------------------------------------------
//  /// Method that saves the user decision on sorting order
//  /// ----------------------------------------------------------
//  Future<bool> setSortingOrder(String value) async {
//    final SharedPreferences prefs = await SharedPreferences.getInstance();
//
//    return prefs.setString('hehe', value);
//  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'amazonc app',
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text('amazon crawl'),
            actions: <Widget>[
              Center(
                child: Text(isServing ? 'service ON' : 'service OFF'),
              ),
              FlatButton.icon(
                icon: Icon(Icons.arrow_forward),
                label: Text('logout'), //`Text` to display
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                  //Code to execute when Floating Action Button is clicked
                  //...
                },
              ),
            ],
            bottom: TabBar(
              unselectedLabelColor: Colors.white.withOpacity(0.3),
              tabs: [
                Tab(text: 'excel'),
                Tab(text: 'url'),
              ],
            ),
          ),
          body: TabBarView(

            children: [
              // ========================================= excel crawl
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Container(
                  child:
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          SizedBox(
                            width: 250,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(child: Text(abspath)),
                                  ],
                                ),
                                Padding(padding: EdgeInsets.all(10.0)),
                                Container(
                                  child: Expanded(
                                      child: ListView.builder(
                                          itemCount: filelists.length,
                                          itemBuilder: (BuildContext ctxt, int index) {
                                            return GestureDetector(
                                                child: Padding(
                                                  padding: EdgeInsets.all(5.0),
                                                  child: Text(basename(filelists[index].path)),
                                                ),
                                                onTap: () => selectTarget(filelists[index])
                                            );
                                          }
                                      )
                                  ),
                                ),
                                new RaisedButton(
                                    child: Text('refresh'),
                                    onPressed: isServing && isEnableAction ? () => refreshTargetList : null
                                ),
                              ],
                            ),
                          ),

                          Flexible(
                            child: Column(
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(child: Text('Load File')),
                                      Expanded(child: Text(targetFileName)),
                                    ],
                                  ),
                                  Row(
                                    children: <Widget>[
                                      Expanded(child: Text('Save Path')),
                                      Expanded(child: Text('${targetMultipleSavepath}')),
                                    ],
                                  ),
                                  Row(
                                    children: <Widget>[
                                      Expanded(child: Text('Progress')),
                                      Expanded(child: Text(targetTotal != 0 ? '${targetProgressed} / ${targetTotal}' : '')),
                                    ],
                                  ),
                                  Padding(padding: EdgeInsets.all(10.0)),
                                  Expanded(
                                      child: Scrollbar(
                                        child: ListView.builder(
                                            itemCount: multiplelist.length,
                                            itemBuilder: (BuildContext ctxt, int index) {
                                              return Row(
                                                children: <Widget>[
                                                  Expanded(
                                                    child: Text('${index+1}. ${multiplelist[index].no}'),
                                                  ),
                                                  Expanded(
                                                    child: Text('->  '),
                                                  ),
                                                  Expanded(
                                                    child: Text('${multiplelist[index].state}'),
                                                  ),
                                                  Expanded(
                                                    child: Text(multiplelist[index].imageCount != 0 ? 'image(${multiplelist[index].crawlCount} / ${multiplelist[index].imageCount})' : '')
                                                  ),
                                                  Expanded(
                                                    child: Text(multiplelist[index].state == CrawlState.Failed ? 'retry(${multiplelist[index].retryCount})' : '')
                                                  )
                                                ],
                                              );
                                            }
                                        )
                                      )

                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Expanded(
                                        child:Row(
                                          children: <Widget>[
                                            Text('retry'),
                                            Checkbox(value: isRetry, onChanged: (value) {
                                              setState(() {
                                                isRetry = value;
                                              });
                                            }),
                                          ],
                                        )
                                      ),
                                      Expanded(
                                        child: RaisedButton(
                                            child: Text('crawl'),
                                            onPressed: isServing && isEnableAction ? () async {
                                              await crawlingMultiple();
                                            } : null),
                                      )
                                    ],

                                  )
                                ],
                              )
                          )
                        ],
                      )

                ),
              ),

              // ========================================= url crawl
              Padding(
                padding: EdgeInsets.all(10.0),
                child: Column( children: <Widget>[
                  Form(
                    key: singleFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TextFormField(
                          decoration: InputDecoration( labelText: '관리번호'),
                          controller: noInputController,
                          validator: (value) {
                            if (value.isEmpty) {
                              return '관리번호를 입력해 주세요.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (term) async {
                            var data = await Clipboard.getData('text/plain');
                            if(data.text.startsWith('http')){
                              urlInputController.text = data.text;
                            }
                            FocusScope.of(context).requestFocus(focusSingleUrl);
                          },
                          onTap: () => noInputController.clear()
                        ),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextFormField(
                                focusNode: focusSingleUrl,
                                decoration: InputDecoration( labelText: '아마존 상품페이지 URL'),
                                controller: urlInputController,
                                validator: (value) {
                                  if (value.isEmpty) {
                                    return 'URL을 입력해 주세요.';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (term) async {
                                  var isservice = SessionManager.isService();
                                  if(isservice == false){
                                    return;
                                  }

                                  if(singleFormKey.currentState.validate()){
                                    setState(() {
                                      singlelist.clear();
                                      var item = CrawlItem(noInputController.text, urlInputController.text);
                                      singlelist.add(item);
                                    });
                                    await crawlingSingle();
                                  }
                                },
                              ),
                            ),
                            SizedBox(
                                width: 70,
                                child: RaisedButton(
                                    child: Text('clear'),
                                    onPressed: isServing && isEnableAction ? () {
                                      urlInputController.clear();
                                    } : null
                                )
                            ),
                            Padding(
                              padding: EdgeInsets.all(5.0),
                            ),
                            SizedBox(
                              width: 70,
                              child: RaisedButton(
                                  child: Text('paste'),
                                  onPressed: isServing && isEnableAction ? () async {
                                    var data = await Clipboard.getData('text/plain');
                                    urlInputController.text = data.text;
                                  } : null
                              )
                            )
                          ],
                        ),

                        Padding(
                          padding: EdgeInsets.all(10.0),
                        ),

                        Center(
                          child: ButtonBar(
                            children: [
                              RaisedButton(
                                child: const Text('Image Crawl'),
                                onPressed: isServing && isEnableAction ? () async {
                                  var isservice = SessionManager.isService();
                                  if(isservice == false){
                                    return;
                                  }

                                  if(singleFormKey.currentState.validate()){
                                    setState(() {
                                      singlelist.clear();
                                      var item = CrawlItem(noInputController.text, urlInputController.text);
                                      singlelist.add(item);
                                    });
                                    await crawlingSingle();

                                  }

                                } : null,
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.all(5.0)
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text('save path')
                      ),
                      Expanded(
                        child: Text('${targetSingleSavepath}')
                      )

                    ],
                  ),
                  Padding(
                      padding: EdgeInsets.all(5.0)
                  ),
                  Expanded(
                      child: ListView.builder
                        (
                          itemCount: singlelist.length,
                          itemBuilder: (BuildContext ctxt, int index) {
                            return Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(singlelist[index].no),
                                ),
                                Text('->     '),
                                Expanded(
                                  child: Text(singlelist[index].state),
                                ),
                                Expanded(
                                  child: Text(singlelist[index].imageCount != 0 ? 'image(${singlelist[index].crawlCount} / ${singlelist[index].imageCount})' : '')
                                )
                              ],

                            );
//                            return Text(lists[index].url);
                          }
                      )

                  )
                ],

                ),
              ),


            ],
          ),
        ),
      ),

      );

  }

  Future crawlingSingle() async {
    print('===== crawling (single) =====');
    if(singlelist == null || singlelist.length == 0){
      print('** no queue');
      return;
    }

    disableAction();

    setState(() {
      targetSingleSavepath = generateSavepath();
    });

    var item = singlelist.first;
    try{
      stateChanging(item, CrawlState.Crawling);
      var savepath = '${abspath}/${targetSingleSavepath}';
      await crawling(item, savepath);

      if(item.imageCount == item.crawlCount && item.imageCount != 0){
        stateChanging(item, CrawlState.Completed);
      }else{
        stateChanging(item, CrawlState.Failed);
      }

    }
    on Exception catch(e){
      stateChanging(item, CrawlState.Failed);
    }

    enableAction();
  }

  Future crawlingMultiple() async {
    disableAction();

    print('===== crawling (multiple) =====');
    if(multiplelist == null || multiplelist.length == 0){
      print('** no queue');
      return;
    }

    do{
      setState(() {
        targetProgressed = 0;
        targetTotal = jobCountChecking(multiplelist);
      });

      for(var item in multiplelist){
        try{
          if(item.state == CrawlState.Completed)
            continue;

          stateChanging(item, CrawlState.Crawling);
          var savepath = '${abspath}/${targetMultipleSavepath}';
          await crawling(item, savepath);

          if(item.imageCount == item.crawlCount && item.imageCount != 0){
            stateChanging(item, CrawlState.Completed);
          }else{
            stateChanging(item, CrawlState.Failed);
          }
        }
        on Exception catch(e){
          stateChanging(item, CrawlState.Failed);
          print('exception!!! - ${e.toString()}');
        }

        setState(() {
          targetProgressed += 1;
        });
      }

    } while(isRetry && hasFailCount(multiplelist));

    enableAction();

  }


  Future crawling(CrawlItem item, String savepath) async {
    print('= crawling start =');
    print('= into : ${item.no} / ${item.url}');

//    var dir = new Directory('${abspath}/${item.no}');
//    if(dir.existsSync()){
//      print('passed!');
//      return;
//    }

    List<String> urls;
    await http.read(item.url).then((contents) {
      //File('${abspath}/${item.no}.html').writeAsStringSync(contents);

      print('= url fetched =');
      urls = inspect2(contents);
      print('= content parsed =');
    });

    var count = urls != null ? urls.length : 0;
    imagecountChanging(item, count);
    print('= image count : ${count}');

    await downloadItem(item, urls, savepath);
    print('= crawling end =');
  }

  Future downloadItem(CrawlItem item, List<String> urls, String savepath) async {
    print('= download start =');
    await Directory(savepath).create().then((Directory dir) async {
      for(var i=0; i<urls.length; i++){
        var savefile = '${dir.path}/${item.no}-${i+1}.jpg';
        await downloadImage(urls[i], savefile);
        if(File(savefile).existsSync()){
          crawlcountAdding(item);
        }
        await Util.sleep();
      }
    });
    print('= download end =');
  }

  Future downloadImage(url, savefile) async {
    await http.get(url).then((response) async {
      await File(savefile).writeAsBytes(response.bodyBytes);
      print('downloaded - ' + savefile);
    });
  }

  List<String> inspect2(String site_code){
    var rs = List<String>();
    var para = new RegExp(r'"ImageBlockATF".*?</script>', dotAll: true);
    if (para.hasMatch(site_code)) {
      var paramatch = para.firstMatch(site_code)[0];
      var exp = RegExp(r'"hiRes":"(.*?)"', multiLine: true);
      var matches = exp.allMatches(paramatch);
      for(Match match in matches) {
        rs.add(match[1]);
      }
    }

    return rs;
  }

  void stateChanging(CrawlItem item, String state){
    setState(() {
      item.state = state;
      if(state == CrawlState.Failed){
        item.retryCount--;
      }
    });

  }

  void imagecountChanging(CrawlItem item, int count){
    item.imageCount = count;
  }

  void crawlcountAdding(CrawlItem item){
    setState(() {
      item.crawlCount += 1;
    });
  }

  disableAction() {
    setState(() {
      isEnableAction = false;
    });
  }
  enableAction() {
    setState(() {
      isEnableAction = true;
    });
  }

  void refreshTargetList(){
    setState(() {
      multiplelist.clear();
      targetFileName = '<not selected>';
      targetMultipleSavepath = '';
      targetTotal = 0;
      targetProgressed = 0;
    });

    var list = List<File>();

    var dir = Directory(abspath);
    if(dir.existsSync() == false)
      return;

    List contents = dir.listSync();
    for (var fileOrDir in contents) {
      if (fileOrDir is File) {
        if(fileOrDir.path.endsWith('.xlsx') || fileOrDir.path.endsWith('.xls')){
          print(fileOrDir.path);
          list.add(fileOrDir);
        }
      }
    }

    setState(() {
      filelists = list;
    });
  }

  void selectTarget(File file) async {
    if(file == null)
      return;

    setState(() {
      multiplelist.clear();
      targetFileName = basename(file.path);
      targetMultipleSavepath = generateSavepath();
      targetTotal = 0;
      targetProgressed = 0;
    });

    var bytes = file.readAsBytesSync();
    var decoder = new SpreadsheetDecoder.decodeBytes(bytes);

    if (decoder.tables.keys == null)
      return;
    var sheetname = decoder.tables.keys.first;
    var table = decoder.tables[sheetname];

    var exp =  new RegExp(r'^https?://.*$');
    var list = new List<CrawlItem>();
    for(var values in table.rows){
      if(values[1] == null || !exp.hasMatch(values[1]))
        continue;
      var item = CrawlItem(values[0].toString(), values[1]);

      setState(() {
        list.add(item);
      });
    }

    setState(() {
      multiplelist = list;
      targetTotal = jobCountChecking(list);
    });
  }

  int jobCountChecking(List<CrawlItem> list){
    int count = 0;
    for(var item in list){
      if(item.state == CrawlState.Completed)
        continue;
      count++;
    }

    return count;
  }

  bool hasFailCount(List<CrawlItem> list){
    for(var item in list){
      if(item.state == CrawlState.Failed && item.retryCount > 0){
        return true;
      }
    }

    return false;
  }

  String generateSavepath(){
    var now = new DateTime.now();
    var formatter = new DateFormat('yyyyMMdd_HHmm');

    return formatter.format(now);
  }

}


//class KeyboardListener extends StatefulWidget {
//  KeyboardListener();
//
//  @override
//  _RawKeyboardListenerState createState() => new _RawKeyboardListenerState();
//}
//
//class _RawKeyboardListenerState extends State<KeyboardListener> {
//  TextEditingController _controller = new TextEditingController();
//  FocusNode _textNode = new FocusNode();
//
//  @override
//  initState() {
//    super.initState();
//  }
//
//  handleKey(RawKeyEventDataAndroid key) {
//    print('KeyCode: ${key.keyCode}, CodePoint: ${key.codePoint}, '
//        'Flags: ${key.flags}, MetaState: ${key.metaState}, '
//        'ScanCode: ${key.scanCode}');
//  }
//
//  @override
//  Widget build(BuildContext context) {
//    return RawKeyboardListener(
//      focusNode: _textNode,
//      onKey: (key) => handleKey(key.data),
//      child: TextField(
//        controller: _controller,
//        focusNode: _textNode,
//      ),
//    );
//  }
//}



class SessionManager {
  static Future<bool> isService() async {
    final connection = await sql.MySqlConnection.connect(settings);
    var results = await connection.query("select is_service from amazonc_setting limit 1");
    bool result = false;

    if(results != null && results.length == 1 && results.first[0] == 1){
      result = true;
    }

    await connection.close();
    return result;
  }

  static Future<bool> isValidUser(userid, passwd) async {
    final connection = await sql.MySqlConnection.connect(settings);
    print("userid: ${userid}, password: ${passwd}");
    var results = await connection.query("select passwd=password('${passwd}') from amazonc_user where userid='${userid}'");
    bool result = false;

    if(results != null && results.length == 1 && results.first[0] == 1) {
      result = true;
    }

    await connection.close();
    return result;
  }

}


class Util {
  static var rand = Random();

  static Future sleep() {
    var next = 1000 + rand.nextInt(1000);
    return new Future.delayed(Duration(milliseconds: next), () => '1');
  }

  static void showAlertDialog(BuildContext context, String message) {
    Widget okButton = FlatButton(
      autofocus: true,
      child: Text("OK"),
      onPressed: () {
        Navigator.pop(context);
      },
    );

    AlertDialog alert = AlertDialog(
      title: Text('Alert'),
      content: Text(message),
      actions: [
        okButton,
      ],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

}



class CrawlItem {
  String no;
  String url;

  int imageCount = 0;
  int crawlCount = 0;
  int retryCount = 5;

  String state = CrawlState.Ready;

  CrawlItem(this.no, this.url);
}

class CrawlState {
  static String Ready = "Ready";
  static String Crawling = "Crawling";
  static String Passed = "Passed";
  static String Completed = "Completed";
  static String Failed = "Failed";
}



