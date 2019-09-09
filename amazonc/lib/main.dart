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
import 'package:file_picker/file_picker.dart';

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
      home: MyHomePage(title: 'amazonc-*'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {

  TextEditingController urlInputController;
  TextEditingController noInputController;

  var lists = List<CrawlItem>.generate(3, (i) => CrawlItem("$i", "hehe_$i"));


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
        child: 
        Scaffold(
          appBar: AppBar(
            title: Text('amazon crawl type'),
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
              // url crawl

              Padding(
                padding: EdgeInsets.all(10.0),
                child: Column( children: <Widget>[
                  TextFormField(
                    decoration: InputDecoration( labelText: '관리번호'),
                    controller: noInputController,
                  ),
                  TextFormField(
                    decoration: InputDecoration( labelText: '아마존 URL'),
                    controller: urlInputController,
                  ),
                  ButtonBar(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      new RaisedButton(onPressed: () async {
                        await FilePicker.getFilePath(type: FileType.IMAGE, fileExtension: "*xlsx");

                      }),
                      new RaisedButton(
                        child: const Text('Clear'),
                        onPressed: () {
                          urlInputController.clear();
                        },
                      ),
                      new RaisedButton(
                        child: const Text('Image Crawl'),
                        onPressed: () async {
                          print("go!!!!!!!!");
                          var c = CrawlItem(noInputController.text, urlInputController.text);
                          var cr = Crawler(c);
                          cr.urlContent();

                          setState(() {
                            lists = List<CrawlItem>();
                            lists.add(c);
                            cr.imageCrawl();
                            c.isCrawl = true;
                          });


//                            return showDialog(
//                              context: context,
//                              builder: (context) {
//                                return AlertDialog(
//                                  content: Text(urlInputController.text),
//                                );
//                              },
//                            );
                        },
                      ),
                    ],
                  ),
                  // Scrollbar(
                  //   child: ListView(
                  //     children: <Widget>[
                  //       Text("hehe")
                  //     ]
                  //   )
                  // ),

                  FloatingActionButton(
                    tooltip: 'Refresh',
                    child: Icon(Icons.replay),
                  ),

                  Expanded(
                      child:
                      ListView.builder
                        (
                          itemCount: lists.length,
                          itemBuilder: (BuildContext ctxt, int index) {
                            return Row(
                              children: <Widget>[
                                Text(lists[index].isCrawl.toString()),
                                Text(" - "),
                                Text(lists[index].no.toString()),
                                Text(" - "),
                                Text(lists[index].url)
                              ],

                            );
//                            return Text(lists[index].url);
                          }
                      )

                  )
                ],

                ),


              ),
              // excel crawl
              Icon(Icons.directions_car),
            ],
          ),
        ),
      ),

      );

  }

}

class CrawlItem {
  String no;
  String url;

  int imageCount;
  int crawlCount;

  bool isCrawl = false;

  CrawlItem(this.no, this.url);
}


class Crawler {
  CrawlItem item;

  List<String> urls;
  String content;

  urlContent() {
    var url = "https://www.amazon.com/Fujifilm-X100F-APS-C-Digital-Camera-Silver/dp/B01N33CT3Z/ref=sr_1_1?crid=339RTF1LI5L74&keywords=fuji+xf100&qid=1567998672&s=gateway&sprefix=fuji+xf10%2Caps%2C465&sr=8-1";
    http.read(url).then((contents) {
      print("crawling --> " + url);
      urls = inspect2(contents);
      for(var url in urls){
        print("images : " + url);
      }

      downloadAll();
    });

  }

  downloadAll(){
    String prefix = '/Users/snailoff/workspace/flutter/works_amazonc/temp/';
    new Directory(prefix + item.no).create().then((Directory dir) {
      for(var i=0; i<urls.length; i++){
        print('${dir.path}/${item.no}-${i+1}.jpg');
        download(urls[i], '${dir.path}/${item.no}-${i+1}.jpg');
      }
    });
  }

  download(url, savefile) {
    http.get(url).then((response) {
      new File(savefile).writeAsBytes(response.bodyBytes);
      print('downloaded - ' + savefile);
    });
  }


  Crawler(this.item);

  String inspect(String site_code){
//    RegExp exp = new RegExp(r"https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)");
    RegExp exp = new RegExp(r'^(.*)$', multiLine: true);

    if(exp.hasMatch(site_code)){
      var block = exp.firstMatch(site_code);
      print('block----------------' + block[0]);
      RegExp detailExp = new RegExp(r'"hiRes":".*?"');
      var matches = detailExp.allMatches(block[0]);

      for(Match match in matches) {
        print(match[0]);
      }

    }else{
      print("not matched!!!!!!!!!!!!!!");
    }
    return "...";
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

  void imageCrawl() {
    Future.delayed(const Duration(seconds: 5), () => "1");
  }


}
