import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sendbird_flutter_demo/main.dart';
import 'package:sendbird_sdk/sendbird_sdk.dart' as Sendbird;

import '../utils.dart';

const CHANNEL_EVENT_HANDLER = 'CHANNEL_EVENT_HANDLER';

class ChannelChatPage extends StatefulWidget {
  final Sendbird.GroupChannel channel;
  final userId;
  final userNickname;

  ChannelChatPage({required this.channel, this.userId, this.userNickname});

  @override
  _ChannelChatPageState createState() => _ChannelChatPageState(
      channel: channel, userId: userId, userNickname: userNickname);
}

class _ChannelChatPageState extends State<ChannelChatPage>
    with Sendbird.ChannelEventHandler {
  Sendbird.GroupChannel channel;
  List<Sendbird.Member> members = [];
  final userId;
  final userNickname;
  bool _isLoading = true;
  bool _isTyping = false;
  bool _membersPanelIsExpanded = false;
  List<Sendbird.BaseMessage>? _messages;
  List<Sendbird.User>? _typingUsers;
  String? _inputMessage;
  TextEditingController _messageInputController = TextEditingController();
  ScrollController _scrollController = new ScrollController();

  _ChannelChatPageState(
      {required this.channel, this.userId, this.userNickname}) {
    members = channel.members;
    getPreviousMessages();
    sendbird.addChannelEventHandler(CHANNEL_EVENT_HANDLER, this);
    channel.markAsRead();
  }

  @override
  void onMessageReceived(
      Sendbird.BaseChannel _channel, Sendbird.BaseMessage message) {
    if (message.sender!.isBlockedByMe ||
        _channel.channelUrl != channel.channelUrl) {
      return;
    }
    setState(() {
      if (_messages == null) {
        _messages = [message];
      } else {
        _messages!.add(message);
      }
    });
  }

  /* https://sendbird.com/docs/chat/v3/flutter/guides/event-handler */
  /* https://sendbird.com/docs/chat/v3/flutter/guides/group-channel-advanced#2-send-typing-indicators-to-other-members */
  @override
  void onTypingStatusUpdated(Sendbird.GroupChannel _channel) {
    if (_channel.channelUrl != channel.channelUrl) {
      return;
    }
    setState(() {
      List<Sendbird.User> typingUsers = _channel.getTypingUsers();
      // ! Performance issue: O(n^2) time needed for finding Users that are blocked Members
      // Fix by either returning List<Members> from the getTypingUsers method
      // Or create a hashmap with all blocked members in this Widget's state
      List<Sendbird.User> typingNonBlockedUsers = typingUsers
          .where((user) =>
              members
                  .where((member) =>
                      member.userId == user.userId && !member.isBlockedByMe)
                  .length >
              0)
          .toList();
      _typingUsers = typingNonBlockedUsers;
    });
  }

  Future getPreviousMessages() async {
    Sendbird.PreviousMessageListQuery query = Sendbird.PreviousMessageListQuery(
        channelType: channel.channelType, channelUrl: channel.channelUrl)
      ..limit = 20
      ..includeMetaArray = true
      ..includeReactions = true;

    try {
      List<Sendbird.BaseMessage> messages = await query.loadNext();
      setState(() {
        _messages = messages;
        _isLoading = false;
        scrollChatToBottom(50);
      });
    } catch (e) {
      debugPrint(e.toString());
      setState(() {
        _isLoading = false;
      });
    }
  }

  void scrollChatToBottom([int? delay]) {
    SchedulerBinding.instance?.addPostFrameCallback((_) =>
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: delay ?? 300),
            curve: Curves.easeOut));
  }

  void onInputChanged(String input) {
    setState(() {
      _inputMessage = input;
      if (!_isTyping) {
        _isTyping = true;
        channel.startTyping();
      } else if (input == "") {
        _isTyping = false;
        channel.endTyping();
      }
    });
  }

  void onSubmit() {
    if (_inputMessage == null) return;

    try {
      final params = Sendbird.UserMessageParams(message: _inputMessage!);
      channel.sendUserMessage(params, onCompleted: (message, error) {
        setState(() {
          _messages!.add(message);
          scrollChatToBottom();
        });
      });
      clearInput();
    } catch (error) {
      setState(() {
        _isTyping = false;
        channel.endTyping();
      });
    }
  }

  void clearInput() {
    _messageInputController.clear();
    channel.endTyping();
    setState(() {
      _inputMessage = null;
      _isTyping = false;
    });
  }

  void blockUser(String userId) async {
    try {
      await sendbird.blockUser(userId);
      setState(() {
        members.where((_m) => _m.userId == userId).first.isBlockedByMe = true;
      });
    } catch (_) {}
  }

  void unBlockUser(String userId) async {
    try {
      await sendbird.unblockUser(userId);
      setState(() {
        members.where((_m) => _m.userId == userId).first.isBlockedByMe = false;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          channel.markAsRead();
          if (_isTyping) {
            channel.endTyping();
          }
          sendbird.removeChannelEventHandler(CHANNEL_EVENT_HANDLER);
          return true;
        },
        child: Scaffold(
            appBar: AppBar(
              leading:
                  BackButton(), // when adding an endDrawer this dissappears by default
              title: getChannelTitle(channel),
              actions: [
                Builder(
                  builder: (context) => IconButton(
                    icon: Icon(Icons.settings),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                )
              ],
            ),
            endDrawer: Drawer(
              child: ListView(children: [
                DrawerHeader(
                    decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        image:
                            (channel.coverUrl != null && channel.coverUrl != "")
                                ? DecorationImage(
                                    image: NetworkImage('${channel.coverUrl}'),
                                    fit: BoxFit.cover)
                                : null),
                    child: Container(
                        alignment: Alignment.bottomCenter,
                        child: getChannelTitle(channel,
                            desc: ' channel settings',
                            fontStyle: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)))),
                ExpansionPanelList(
                  expansionCallback: (int index, bool isExpanded) {
                    setState(() {
                      if (index == 0) {
                        _membersPanelIsExpanded = !isExpanded;
                      }
                    });
                  },
                  children: [
                    ExpansionPanel(
                        isExpanded: _membersPanelIsExpanded,
                        canTapOnHeader: true,
                        headerBuilder:
                            (BuildContext context, bool isExpanded) => ListTile(
                                  leading: Icon(Icons.people),
                                  title: Text('${members.length} Members'),
                                ),
                        body: Column(
                          children: getMembersList(members,
                              blockUser: blockUser,
                              unBlockUser: unBlockUser,
                              currentUserId: userId),
                        ))
                  ],
                )
              ]),
            ),
            body: (_isLoading && _messages == null)
                ? Center(child: CircularProgressIndicator())
                : Column(children: [
                    Expanded(
                      child: Container(
                          padding: EdgeInsets.all(15),
                          child: _messages != null
                              ? ListView.builder(
                                  controller: _scrollController,
                                  itemCount: _messages?.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    return ChatMessage(
                                        _messages![index], context,
                                        margin: EdgeInsets.only(bottom: 10),
                                        userId: userId,
                                        userNickname: userNickname,
                                        previousMessage: index > 0
                                            ? _messages![index - 1]
                                            : null);
                                  },
                                )
                              : Center(
                                  child:
                                      Text('No messages in this group yet.'))),
                    ),
                    Container(
                      padding: EdgeInsets.only(left: 15),
                      child: getTypingUsers(_typingUsers),
                      alignment: Alignment.bottomLeft,
                    ),
                    Container(
                      padding: EdgeInsets.only(left: 15),
                      margin: EdgeInsets.only(bottom: 60),
                      child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                                child: TextFormField(
                              controller: _messageInputController,
                              onChanged: onInputChanged,
                              decoration: InputDecoration(
                                  suffixIcon:
                                      _messageInputController.text.length > 0
                                          ? IconButton(
                                              icon: Icon(
                                                Icons.cancel,
                                                color: Colors.black54,
                                              ),
                                              onPressed: clearInput,
                                            )
                                          : null,
                                  border: OutlineInputBorder(),
                                  hintText: 'Say something...'),
                            )),
                            TextButton(
                                onPressed:
                                    _messageInputController.text.length > 0
                                        ? onSubmit
                                        : null,
                                child: Icon(Icons.send)),
                          ]),
                    )
                  ])));
  }
}

class ChatMessage extends Container {
  final Sendbird.BaseMessage message;
  final Sendbird.BaseMessage? previousMessage;
  final BuildContext context;
  final margin;
  final userId;
  final userNickname;

  ChatMessage(this.message, this.context,
      {this.margin, this.userId, this.userNickname, this.previousMessage});

  @override
  Widget get child {
    if (message is Sendbird.FileMessage) {
      return Text('file message');
    }
    var alignment = MainAxisAlignment.start;
    var backgroundColor = Theme.of(context).primaryColor;
    var textColor = Colors.white;
    var messageString = message.message;
    var textDirection = TextDirection.ltr;

    if (message is Sendbird.AdminMessage) {
      alignment = MainAxisAlignment.center;
      backgroundColor = Colors.yellow;
      textColor = Theme.of(context).primaryColor;
      messageString = 'Admin: ' + message.message;
    }

    if (message.sender != null && message.sender?.userId == userId) {
      backgroundColor = Colors.black12;
      textColor = Theme.of(context).primaryColor;
      textDirection = TextDirection.rtl;
    }

    return Row(
        textDirection: textDirection,
        mainAxisAlignment: alignment,
        children: [
          (message.sender?.userId != userId &&
                  (previousMessage?.sender?.userId != message.sender?.userId))
              ? getChatMessageUserAvatar(message)
              : Padding(padding: EdgeInsets.only(left: 45)),
          Container(
            decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.all(Radius.elliptical(10, 10))),
            padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
            margin: message is Sendbird.AdminMessage
                ? EdgeInsets.only(top: 20)
                : EdgeInsets.only(left: 10, right: 10),
            child: FittedBox(
                fit: BoxFit.contain,
                child: Text(messageString, style: TextStyle(color: textColor))),
          ),
        ]);
  }
}
