import 'package:flutter/material.dart';
import 'package:sendbird_flutter_demo/utils.dart';

import 'channel_list.dart';

class LoginPage extends StatefulWidget {
  LoginPage() : super();

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? _userId;
  String? _userNickname;

  void onUserIdInputChange(String input) {
    setState(() {
      _userId = input.trim();
    });
  }

  void onUserNicknameInputChange(String value) {
    setState(() {
      _userNickname = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login page'),
      ),
      body: Center(
          child: Form(
              child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextFormField(
                decoration:
                    const InputDecoration(hintText: 'Enter your user ID'),
                onChanged: onUserIdInputChange,
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 10),
              ),
              TextFormField(
                decoration:
                    const InputDecoration(hintText: 'Enter your nickname'),
                onChanged: onUserNicknameInputChange,
              ),
              Padding(
                padding: EdgeInsets.only(top: 10),
              ),
              ElevatedButton(
                  onPressed: (_userId != null && _userId != "")
                      ? () async {
                          await connect(_userId!, nickname: _userNickname);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ChannelListPage(
                                      _userId!, _userNickname)));
                        }
                      : null,
                  child: const Text('Enter'))
            ]),
      ))),
    );
  }
}
