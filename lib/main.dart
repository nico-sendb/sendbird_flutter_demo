import 'package:flutter/material.dart';
import 'package:sendbird_flutter_demo/screens/login.dart';
import 'package:sendbird_sdk/sendbird_sdk.dart' as Sendbird;

void main() {
  runApp(MyApp());
}

final sendbird =
    Sendbird.SendbirdSdk(appId: 'AFE50EBE-483A-4B80-9DA3-31C500543288');

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sendbird Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        var routes = <String, WidgetBuilder>{
          '/': (context) => LoginPage(),
        };
        WidgetBuilder builder = routes[settings.name]!;
        return MaterialPageRoute(
            builder: (ctx) => builder(ctx), settings: settings);
      },
    );
  }
}
