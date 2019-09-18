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

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mysql1/mysql1.dart' as sql;
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

var settings = new sql.ConnectionSettings(
  host: 'jobbot.co.kr',
  port: 3306,
  user: 'amazonc',
  password: 'skantkfkd55',
  db: 'amazonc',
);

void main() {
  // See https://github.com/flutter/flutter/wiki/Desktop-shells#target-platform-override
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'amazonc',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // See https://github.com/flutter/flutter/wiki/Desktop-shells#fonts
        fontFamily: 'Roboto',
      ),
//      home: LoginPage(),
        home: CrawlPage(),
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

  @override
  void initState() {
    useridInputController = TextEditingController();
    passwdInputController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    useridInputController.dispose();
    passwdInputController.dispose();
    super.dispose();
  }

  Future<bool> isService() async {
    final connection = await sql.MySqlConnection.connect(settings);
    var results = await connection.query("select is_service from amazonc_setting limit 1");
    bool result = false;

    if(results != null && results.length == 1 && results.first[0] == 1){
      result = true;
    }

    await connection.close();
    return result;
  }

  Future<bool> isValidUser() async {
    final connection = await sql.MySqlConnection.connect(settings);
    var userid = useridInputController != null ? useridInputController.text : "";
    var passwd = passwdInputController != null ? passwdInputController.text : "";
    print("userid: ${userid}, password: ${passwd}");
    var results = await connection.query("select passwd=password('${passwd}') from amazonc_user where userid='${userid}'");
    bool result = false;

    if(results != null && results.length == 1 && results.first[0] == 1) {
      result = true;
    }

    await connection.close();
    return result;
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
                          decoration: InputDecoration( labelText: 'ID'),
                          controller: useridInputController,
                          validator: (value) {
                            if (value.isEmpty) {
                              return 'ID 를 입력해주세요.';
                            }
                            return null;
                          },
                        ),
                      TextFormField(
                        decoration: InputDecoration( labelText: 'PASSWORD'),
                        controller: passwdInputController,
                        validator: (value) {
                          if (value.isEmpty) {
                            return 'PASSWORD 를 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                      RaisedButton(
                        onPressed: () async {
                          if(loginFormKey.currentState.validate()) {
                            var isRun = await isService();
                            var isValid = await isValidUser();

                            if(await isService() && await isValidUser()){
                              Navigator.pushReplacementNamed(context, "/home");

                            }else{
                              await showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  // return object of type Dialog
                                  return AlertDialog(
//                              title: new Text("Alert Dialog title"),
                                    content: new Text("존재하지 않는 User 이거나 Password가 잘못되었습니다. "),
                                    actions: <Widget>[
                                      // usually buttons at the bottom of the dialog
                                      new FlatButton(
                                        child: new Text("Close"),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );

                            }
                          }

                        },
                        child: Text('login'),

                      ),
                    ],
                  )
                ,)

          )
      ),

    );
  }

}



class CrawlPage extends StatefulWidget {
  CrawlPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _CrawlPageState createState() => _CrawlPageState();
}



class _CrawlPageState extends State<CrawlPage> with SingleTickerProviderStateMixin {

  // multiple
  var multiplelist = List<CrawlItem>();
  var filelists = List<File>();
  var targetFileName = "<not selected>";

  // single
  var singlelist = List<CrawlItem>();
  var isDisableAction = false;
  final singleFormKey = GlobalKey<FormState>();

  TextEditingController urlInputController;
  TextEditingController noInputController;


  @override
  void initState() {
    urlInputController = TextEditingController();
    noInputController = TextEditingController();
    super.initState();

    refreshTargetList();

//    print("==================");
//    var test = getSortingOrder().then((_) => print(_));
//    setSortingOrder("lala");
//    print("==================");

  }

  @override
  void dispose() {
    urlInputController.dispose();
    noInputController.dispose();
    super.dispose();
  }

  Future<String> getSortingOrder() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    return prefs.getString("hehe") ?? 'name';
  }

  /// ----------------------------------------------------------
  /// Method that saves the user decision on sorting order
  /// ----------------------------------------------------------
  Future<bool> setSortingOrder(String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    return prefs.setString("hehe", value);
  }


  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: "amazonc app",
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text('amazon crawl'),
            bottom: TabBar(
              unselectedLabelColor: Colors.white.withOpacity(0.3),
              tabs: [
                Tab(text: "excel"),
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
                          Flexible(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: <Widget>[
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
                                    child: Text("refresh"),
                                    onPressed: refreshTargetList
                                ),
                              ],
                            ),
                          ),

                          Flexible(
                            child: Column(
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Text(targetFileName),
                                    ],
                                  ),
                                  Expanded(
                                      child:
                                      ListView.builder(
                                          itemCount: multiplelist.length,
                                          itemBuilder: (BuildContext ctxt, int index) {
                                            return Row(
                                              children: <Widget>[
                                                Expanded(
                                                  child: Text(multiplelist[index].no),
                                                ),
                                                Text("->     "),
                                                Expanded(
                                                  child: Text(multiplelist[index].state),
                                                )
                                              ],
                                            );
                                          }
                                      )

                                  ),
                                  RaisedButton(
                                      child: Text("crawl"),
                                      onPressed: () async {
                                        await crawlingMultiple();
                                      }),
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
                        ),
                        TextFormField(
                          decoration: InputDecoration( labelText: '아마존 상품페이지 URL'),
                          controller: urlInputController,
                          validator: (value) {
                            if (value.isEmpty) {
                              return 'URL을 입력해 주세요.';
                            }
                            return null;
                          },
                        ),
                        ButtonBar(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            RaisedButton(
                              child: const Text('Reset'),
                              onPressed: isDisableAction ? null : singleCrawlingReset,
                            ),
                            RaisedButton(
                              child: const Text('Image Crawl'),
                              onPressed: isDisableAction ? null : () async {
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
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                      child:
                      ListView.builder
                        (
                          itemCount: singlelist.length,
                          itemBuilder: (BuildContext ctxt, int index) {
                            return Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(singlelist[index].no),
                                ),
                                Text("->     "),
                                Expanded(
                                  child: Text(singlelist[index].state),
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


  crawlingSingle() async {
    print("===== crawling (single) =====");
    if(singlelist == null || singlelist.length == 0){
      print("** no queue");
      return;
    }

    disableAction();

    var item = singlelist.first;
    try{
      await crawling(item);
      singleStateChanging(item, CrawlState.Completed);

    }
    on Exception catch(e){
      singleStateChanging(item, CrawlState.Failed);
    }

    enableAction();
  }

  crawlingMultiple() async {
    print("===== crawling (multiple) =====");
    if(multiplelist == null || multiplelist.length == 0){
      print("** no queue");
      return;
    }

    disableAction();

    for(var item in multiplelist){

      try{
        await crawling(item);
        multipleStateChanging(item, CrawlState.Completed);
      }
      on Exception catch(e){
        multipleStateChanging(item, CrawlState.Failed);
      }
    }

    enableAction();
  }

  crawling(CrawlItem item) async {
    print("= crawling start =");

    singleStateChanging(item, CrawlState.Crawling);
//    var url = "https://www.amazon.com/Fujifilm-X100F-APS-C-Digital-Camera-Silver/dp/B01N33CT3Z/ref=sr_1_1?crid=339RTF1LI5L74&keywords=fuji+xf100&qid=1567998672&s=gateway&sprefix=fuji+xf10%2Caps%2C465&sr=8-1";
//    var url = "https://www.amazon.com/Fotodiox-Lens-Mount-Adapter-Mirrorless/dp/B00VTZ1J9Q?ref_=ast_slp_dp";
    var url = item.url;
    List<String> urls;

    print("= url : " + url);
    await http.read(url).then((contents) {
      print("= url fetched =");
      urls = inspect2(contents);
      print("= content parsed =");
    });
    print("= image count : ${urls != null ? urls.length : 0}");

    await downloadAll(item, urls);

    print("= crawling end =");
  }

  downloadAll(CrawlItem item, List<String> urls) async {
    print("= download start =");
    String prefix = '/Users/snailoff/workspace/flutter/works_amazonc/temp/';
    await Directory(prefix + item.no).create().then((Directory dir) async {
      for(var i=0; i<urls.length; i++){
        await download(urls[i], '${dir.path}/${item.no}-${i+1}.jpg');
      }
    });
    print("= download end =");
  }

  download(url, savefile) async {
    await http.get(url).then((response) {
      File(savefile).writeAsBytes(response.bodyBytes);
      print('downloaded - ' + savefile);
    });
  }

  List<String> inspect2(String site_code){
//    RegExp exp = new RegExp(r"https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)");
    var rs = List<String>();
    var exp = RegExp(r'"hiRes":"(.*?)"', multiLine: true);
    var matches = exp.allMatches(site_code);
    for(Match match in matches) {
      rs.add(match[1]);
    }

    return rs;
  }

  singleStateChanging(CrawlItem item, String state){
    for(var c in singlelist){
      if(c.no == item.no){
        setState(() {
          c.state = state;
        });
      }
    }
  }

  multipleStateChanging(CrawlItem item, String state){
    for(var c in singlelist){
      if(c.no == item.no){
        setState(() {
          c.state = state;
        });
      }
    }
  }

  disableAction() {
    setState(() {
      isDisableAction = true;
    });
  }
  enableAction() {
    setState(() {
      isDisableAction = false;
    });
  }


  void refreshTargetList(){
    multipleCrawlingReset();

    var list = List<File>();

    var dir = Directory('/Users/snailoff/workspace/flutter/works_amazonc/temp');
    List contents = dir.listSync();
    for (var fileOrDir in contents) {
      if (fileOrDir is File) {
        if(fileOrDir.path.endsWith(".xlsx") || fileOrDir.path.endsWith(".xls")){
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
    });

    var bytes = file.readAsBytesSync();
    var decoder = new SpreadsheetDecoder.decodeBytes(bytes);

    if (decoder.tables.keys == null)
      return;
    var sheetname = decoder.tables.keys.first;
    var table = decoder.tables[sheetname];

    var exp =  new RegExp(r"^https?://.*$");
    for(var values in table.rows){
      if(values[1] == null || !exp.hasMatch(values[1]))
        continue;
      var item = CrawlItem(values[0].toString(), values[1]);

      setState(() {
        multiplelist.add(item);
      });
    }
  }


  void multipleCrawlingReset() {
    setState(() {
      multiplelist.clear();
      targetFileName = "<not selected>";
    });

  }

  void singleCrawlingReset() {
    print("### single tapp!!");
    noInputController.clear();
    urlInputController.clear();

    setState(() {
      singlelist.clear();
    });
  }

}

class CrawlItem {
  String no;
  String url;

  int imageCount;
  int crawlCount;

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



