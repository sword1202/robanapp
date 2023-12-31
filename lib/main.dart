// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:social_media_app/Chats.dart';
import 'package:social_media_app/LoginWithEmail.dart';
import 'package:social_media_app/LoginWithUsername.dart';
import 'package:social_media_app/SignUp.dart';
import 'package:social_media_app/caching/sqfliteConfiguration.dart';
import 'package:social_media_app/custom/CustomButton.dart';
import 'package:social_media_app/firebase/firebase_constants.dart';
import 'package:social_media_app/observer/GlobalObserver.dart';
import 'package:social_media_app/socket/main.dart';
import 'package:social_media_app/state/main.dart';
import 'package:social_media_app/styles/AppStyles.dart';
import 'package:social_media_app/transition/RightToLeftTransition.dart';
import 'MainPage.dart';
import 'package:social_media_app/appdata/GlobalLibrary.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async{
  try {
    WidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = MyHttpOverrides();
    await DatabaseHelper().initDatabase();
    GlobalObserver globalObserver = GlobalObserver();
    WidgetsBinding.instance.addObserver(globalObserver);
    await firebaseInitialization;
    await firebaseAppCheckInitialization;
    runApp(const MyApp());
  } on Exception catch (e) {
    doSomethingWithException(e);
  }
  //WidgetsBinding.instance.removeObserver(globalObserver);
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.dark(),
      onGenerateRoute: (settings) {
        if (settings.name == "/chats-list") {
          return generatePageRouteBuilder(settings, const ChatsWidget());
        }
        return null;
      },
      routes: {
        // When navigating to the "/" route, build the FirstScreen widget.
        '/': (context) => const MyHomePage(title: 'Social Media App'),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ValueNotifier<bool?> isLoginToAccount = ValueNotifier(null);  
  
  void connect(){
    socket.connect();
    socket.on('error', (_) => debugPrint("Sorry, there seems to be an issue with the connection!"));
    socket.on('connect_error', (err) => debugPrint('$err'));
    socket.on('connect', (_){
      String ? id = socket.id!;
      if(mounted){
        appStateClass.socketID = id;
      }
      debugPrint('$id is socket id');
    });
  }

  void defaultLogin() async{
    try {
      List<String> getCurrentUserIDList = await DatabaseHelper().fetchAllUsers();
      List lifecycleData = await DatabaseHelper().getAllUsersLifecycleData();
      bool hasPassedLoginLimit = lifecycleData.isEmpty ? false : lifecycleData[0]['last_lifecycle_time'].isEmpty ? false : DateTime.now().difference(DateTime.parse(lifecycleData[0]['last_lifecycle_time']).toLocal()).inMinutes > 10;
      if(getCurrentUserIDList.isNotEmpty && lifecycleData[0]['user_id'].isNotEmpty && !hasPassedLoginLimit){
        var verifyAccountExistence = await checkAccountExists(getCurrentUserIDList[0]);
        if(verifyAccountExistence['message'] == 'Successfully checked account existence'){
          if(verifyAccountExistence['exists'] == true){
            appStateClass.currentID = getCurrentUserIDList[0];
            runDelay(() => Navigator.push(
              context,
              SliderRightToLeftRoute(
                page: const MainPageWidget()
              )
            ), navigatorDelayTime);
            if(mounted){
              isLoginToAccount.value = true;
            }
          }
        }else{
          if(mounted){
            isLoginToAccount.value = false;
          }
        }
      }else{
        if(mounted){
          isLoginToAccount.value = false;
        }
      }
    } on Exception catch (e) {
      doSomethingWithException(e);
    }
  }

  Future<dynamic> checkAccountExists(String userID) async{
    var dio = Dio();
    String stringified = jsonEncode({
      'userID': userID
    });
    var res = await dio.get('$serverDomainAddress/users/checkAccountExists', data: stringified);
    return res.data;
  }

  @override
  void initState() {
    super.initState();
    if(mounted){
      connect();
      defaultLogin();
    }
  }

  @override void dispose(){
    super.dispose();
    isLoginToAccount.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: isLoginToAccount,
      builder: (context, bool? isLoginToAccountValue, child){
        if(isLoginToAccountValue == false){
          return Scaffold(
            body: Center(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: defaultFrontPageDecoration,
                child: Stack(
                  children: [
                    Positioned(
                      left: -getScreenWidth() * 0.45,
                      top: -getScreenWidth() * 0.25,
                      child: Container(
                        width: getScreenWidth(),
                        height: getScreenWidth(),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(200),
                          color: Colors.amber.withOpacity(0.65)
                        ),
                      ),
                    ),
                    Positioned(
                      right: -getScreenWidth() * 0.55,
                      top: getScreenWidth() * 0.85,
                      child: Container(
                        width: getScreenWidth(),
                        height: getScreenWidth(),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(200),
                          color: Colors.blue.withOpacity(0.8)
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const Text('Social Media App', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.black)),
                                SizedBox(height: getScreenHeight() * 0.085),
                              ],
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[                        
                                CustomButton(
                                  width: getScreenWidth() * 0.6, height: getScreenHeight() * 0.075, 
                                  buttonColor: const Color.fromARGB(255, 151, 145, 87), buttonText: 'Sign Up', 
                                  onTapped: (){
                                    runDelay((){
                                      resetReduxData(context);
                                      runDelay(() => Navigator.push(
                                        context,
                                        SliderRightToLeftRoute(
                                          page: const SignUpStateless()
                                        )
                                      ), navigatorDelayTime);
                                    }, actionDelayTime);
                                  }, 
                                  setBorderRadius: true
                                ),
                                SizedBox(height: getScreenHeight() * 0.02),
                                CustomButton(
                                  width: getScreenWidth() * 0.6, height: getScreenHeight() * 0.075, 
                                  buttonColor: const Color.fromARGB(255, 151, 145, 87), buttonText: 'Login With Email', 
                                  onTapped: (){
                                    runDelay((){
                                      resetReduxData(context);
                                      runDelay(() => Navigator.push(
                                        context,
                                        SliderRightToLeftRoute(
                                          page: const LoginWithEmailStateless()
                                        )
                                      ), navigatorDelayTime);
                                    }, actionDelayTime);
                                  },
                                  setBorderRadius: true
                                ),
                                SizedBox(height: getScreenHeight() * 0.02),
                                CustomButton(
                                  width: getScreenWidth() * 0.6, height: getScreenHeight() * 0.075, 
                                  buttonColor: const Color.fromARGB(255, 151, 145, 87), buttonText: 'Login With Username', 
                                  onTapped: (){
                                    runDelay((){
                                      resetReduxData(context);
                                      runDelay(() => Navigator.push(
                                        context,
                                        SliderRightToLeftRoute(
                                          page: const LoginWithUsernameStateless()
                                        )
                                      ), navigatorDelayTime);
                                    }, actionDelayTime);
                                  },
                                  setBorderRadius: true
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                )
              ),
            )
          );
        }else{
          if(isLoginToAccountValue == null){
            return Scaffold(
              body: Center(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: defaultFrontPageDecoration,
                  child: const Icon(FontAwesomeIcons.solidCircleUser, size: 100, color: Colors.black)
                )
              )
            );
          }
          return Scaffold(
            appBar: AppBar(
              leading: defaultLeadingWidget(context),
              title: const Text('Feed'), 
              titleSpacing: defaultAppBarTitleSpacing,
              flexibleSpace: Container(
                decoration: defaultAppBarDecoration
              )
            ),
            body: Container()
          );
        }
      }
    );
  }
}