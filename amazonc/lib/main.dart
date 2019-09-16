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
      home: LoginPage(),
      routes: {
        "/login": (_) => new LoginPage(),
        "/home": (_) => new CrawlPage()
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

  TextEditingController urlInputController;
  TextEditingController noInputController;

  var isDisableAction = false;

  var lists = List<CrawlItem>();

  final singleFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    urlInputController = TextEditingController();
    noInputController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    urlInputController.dispose();
    noInputController.dispose();
    super.dispose();
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
              // excel crawl
              Icon(Icons.directions_car),
              // url crawl

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
                            new RaisedButton(
                              child: const Text('Reset'),
                              onPressed: isDisableAction ? null : singleCrawlingReset,
                            ),
                            new RaisedButton(
                              child: const Text('Image Crawl'),
                              onPressed: isDisableAction ? null : () async {
                                if(singleFormKey.currentState.validate()){
                                  resetQueue();
                                  var item = CrawlItem(noInputController.text, urlInputController.text);
                                  addToQueue(item);
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
                          itemCount: lists.length,
                          itemBuilder: (BuildContext ctxt, int index) {
                            return Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(lists[index].no),
                                ),
                                Text("->     "),
                                Expanded(
                                  child: Text(lists[index].state),
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
    if(lists == null || lists.length == 0){
      print("** no queue");
      return;
    }

    disableAction();

    var item = lists.first;
    try{
      await crawling(item);
      stateChanging(item, CrawlState.Completed);

    }
    on Exception catch(e){
      stateChanging(item, CrawlState.Failed);
    }

    enableAction();
  }

  crawlingMultiple() async {
    print("===== crawling (multiple) =====");
    if(lists == null || lists.length == 0){
      print("** no queue");
      return;
    }

    disableAction();

    for(var item in lists){

      try{
        await crawling(item);
        stateChanging(item, CrawlState.Completed);
      }
      on Exception catch(e){
        stateChanging(item, CrawlState.Failed);
      }
    }

    enableAction();
  }

  crawling(CrawlItem item) async {
    print("= crawling start =");

    stateChanging(item, CrawlState.Crawling);
//    var url = "https://www.amazon.com/Fujifilm-X100F-APS-C-Digital-Camera-Silver/dp/B01N33CT3Z/ref=sr_1_1?crid=339RTF1LI5L74&keywords=fuji+xf100&qid=1567998672&s=gateway&sprefix=fuji+xf10%2Caps%2C465&sr=8-1";
    var url = "https://www.amazon.com/Fotodiox-Lens-Mount-Adapter-Mirrorless/dp/B00VTZ1J9Q?ref_=ast_slp_dp";
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
    await new Directory(prefix + item.no).create().then((Directory dir) async {
      for(var i=0; i<urls.length; i++){
        await download(urls[i], '${dir.path}/${item.no}-${i+1}.jpg');
      }
    });
    print("= download end =");
  }

  download(url, savefile) async {
    await http.get(url).then((response) {
      new File(savefile).writeAsBytes(response.bodyBytes);
      print('downloaded - ' + savefile);
    });
  }

  List<String> inspect2(String site_code){
//    RegExp exp = new RegExp(r"https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)");
    List<String> rs = List<String>();
    RegExp exp = new RegExp(r'"hiRes":"(.*?)"', multiLine: true);
    var matches = exp.allMatches(site_code);
    for(Match match in matches) {
      rs.add(match[1]);
    }

    return rs;
  }

  stateChanging(CrawlItem item, String state){
    for(var c in lists){
      if(c.no == item.no){
        setState(() {
          c.state = state;
        });
      }
    }
  }

  addToQueue(CrawlItem item){
    setState(() {
      lists.add(item);
    });
  }

  resetQueue(){
    setState(() {
      lists.clear();
    });
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


  void singleCrawlingReset() {
    noInputController.clear();
    urlInputController.clear();

    setState(() {
      lists = List<CrawlItem>();
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

