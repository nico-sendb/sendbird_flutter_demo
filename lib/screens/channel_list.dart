import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sendbird_flutter_demo/Firebase.dart';
import 'package:sendbird_flutter_demo/main.dart';
import 'package:sendbird_flutter_demo/screens/channel_chat.dart';
import 'package:sendbird_flutter_demo/utils.dart';
import 'package:sendbird_sdk/sendbird_sdk.dart' as Sendbird;

const CHANNEL_LIST_EVENT_HANDLER = 'CHANNEL_LIST_EVENT_HANDLER';

class ChannelListPage extends StatefulWidget {
  final String userId;
  final String? userNickname;

  ChannelListPage(this.userId, this.userNickname);

  @override
  _ChannelListPageState createState() =>
      _ChannelListPageState(this.userId, this.userNickname);
}

class _ChannelListPageState extends State<ChannelListPage>
    with Sendbird.ChannelEventHandler {
  final String _userId;
  final String? _userNickname;
  bool _isLoading = true;
  late Future<FirebaseMessaging> messaging;

  List<Sendbird.GroupChannel>? channels;

  _ChannelListPageState(this._userId, this._userNickname) {
    retrieveUserChannels();
    sendbird.addChannelEventHandler(CHANNEL_LIST_EVENT_HANDLER, this);
    FirebasePush firebase = FirebasePush();
    this.messaging = firebase.messaging;
  }

  @override
  void onMessageReceived(
      Sendbird.BaseChannel _channel, Sendbird.BaseMessage message) {
    setState(() {
      _isLoading = true;
    });
    retrieveUserChannels();
  }

  @override
  void onReadReceiptUpdated(Sendbird.GroupChannel channel) {
    debugPrint('unreadMessageCount: ${channel.unreadMessageCount}');
    if (channels == null)
      return setState(() {
        int index = channels!.indexOf(channel);
        channels![index] = channel;
      });
  }

  Future<void> retrieveUserChannels() async {
    try {
      Sendbird.GroupChannelListQuery query =
          new Sendbird.GroupChannelListQuery()..userIdsIncludeIn = [_userId];
      List<Sendbird.GroupChannel> sbChannels = await query.loadNext();
      setState(() {
        channels = sbChannels;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('retrieveUserChannels error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Sendbird.User>> retrieveAllUsers() async {
    final listQuery = Sendbird.ApplicationUserListQuery();

    try {
      final users = await listQuery.loadNext();
      users.removeWhere((user) => user.userId == _userId);
      return users;
    } catch (_e) {
      return [];
    }
  }

  String getNewChannelTitleFallback(userIds) {
    StringBuffer membersTitle = StringBuffer();
    membersTitle.write(_userId);
    userIds.forEach((userId) {
      membersTitle.write(' / ' + userId);
    });
    return membersTitle.toString();
  }

  Future<Sendbird.GroupChannel?> createNewChannel(
      List<Sendbird.User> users, String name) async {
    try {
      List<String> userIds =
          users.map<String>((user) => user.userId.toString()).toList();
      final params = Sendbird.GroupChannelParams()
        ..userIds = userIds
        ..isDistinct = true
        ..name = name == '' ? getNewChannelTitleFallback(userIds) : name;
      final channel = await Sendbird.GroupChannel.createChannel(params);
      return channel;
    } catch (_e) {
      debugPrint('createNewChannel error: ' + _e.toString());
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          sendbird.removeChannelEventHandler(CHANNEL_LIST_EVENT_HANDLER);
          return true;
        },
        child: Scaffold(
            appBar: AppBar(
              title: Text('Channel List page'),
              actions: [
                IconButton(
                  onPressed: () async {
                    List<Sendbird.User> users = await retrieveAllUsers();
                    var results = await showDialog(
                        context: context,
                        builder: (BuildContext context) =>
                            UsersListDialog(users));
                    if (results == null) {
                      // dialog has been dismissed
                      return;
                    }
                    List<Sendbird.User> selectedUsers = results[0];
                    String groupName = results[1];
                    Sendbird.GroupChannel? channel =
                        await createNewChannel(selectedUsers, groupName);
                    if (channel != null) {
                      // navigate to the newly created channel
                      Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ChannelChatPage(
                                      channel: channel,
                                      userId: _userId,
                                      userNickname: _userNickname)))
                          .whenComplete(retrieveUserChannels);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'There was an error. Please try again later.')));
                    }
                  },
                  tooltip: 'Create a new channel',
                  icon: Icon(Icons.add_box),
                )
              ],
            ),
            body: Center(
                child: (channels != null && channels!.length > 0)
                    ? ListView.builder(
                        itemCount: channels?.length,
                        itemBuilder: (BuildContext context, int index) {
                          return ChannelListItem(
                              context: context,
                              channel: channels![index],
                              userId: _userId,
                              userNickname: _userNickname,
                              retrieveUserChannels: retrieveUserChannels);
                        },
                      )
                    : _isLoading
                        ? CircularProgressIndicator()
                        : Container(
                            padding: EdgeInsets.all(50),
                            child: Text(
                              'No channels where found. Use the button on the top right corner to create a new channel.',
                              textAlign: TextAlign.center,
                            ),
                          ))));
  }
}

class ChannelListItem extends Container {
  final Sendbird.GroupChannel channel;
  final context;
  final userId;
  final userNickname;
  final retrieveUserChannels;

  ChannelListItem(
      {this.context,
      required this.channel,
      this.userId,
      this.userNickname,
      this.retrieveUserChannels});

  @override
  Widget get child {
    return Card(
        child: ListTile(
            minVerticalPadding: 18,
            title: getChannelTitle(channel),
            subtitle: getChannelListItemSubtitle(channel),
            leading: getChannelThumbnail(channel),
            trailing: getUnreadMessageCount(channel),
            isThreeLine: true,
            onTap: () {
              sendbird.removeChannelEventHandler(CHANNEL_LIST_EVENT_HANDLER);
              Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ChannelChatPage(
                              channel: channel,
                              userId: userId,
                              userNickname: userNickname)))
                  .whenComplete(retrieveUserChannels);
            }));
  }
}

class UsersListDialog extends StatefulWidget {
  final List<Sendbird.User> users;

  UsersListDialog(this.users);
  @override
  State<StatefulWidget> createState() => _UsersListDialogState(this.users);
}

class _UsersListDialogState extends State<UsersListDialog> {
  String _groupName = '';
  List<Sendbird.User> users;
  List<Sendbird.User> _selectedUsers = [];

  _UsersListDialogState(this.users);

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
        contentPadding: EdgeInsets.all(10),
        title: Text('New group settings'),
        children: [
          Padding(padding: EdgeInsets.only(top: 25)),
          Text('Group name:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Container(
            height: 50,
            padding: EdgeInsets.only(left: 20, right: 20),
            child: TextFormField(
              decoration:
                  const InputDecoration(hintText: 'Enter group\'s name'),
              onChanged: (String input) {
                setState(() {
                  _groupName = input.trim();
                });
              },
            ),
          ),
          Padding(padding: EdgeInsets.only(top: 25)),
          Text('Select users:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Container(
            height: 250,
            width: 150,
            child: ListView(
              shrinkWrap: true,
              children: [
                ...users
                    .map<Widget>((user) => CheckboxListTile(
                        title: Text(user.nickname == ''
                            ? '<No nickname>'
                            : user.nickname),
                        subtitle: Text(user.userId),
                        value: _selectedUsers.contains(user),
                        onChanged: (selected) {
                          setState(() {
                            selected == true
                                ? _selectedUsers.add(user)
                                : _selectedUsers.remove(user);
                          });
                        }))
                    .toList(),
              ],
            ),
          ),
          Container(
            height: 50,
            padding: EdgeInsets.only(left: 20, right: 20),
            child: ElevatedButton(
                onPressed: _selectedUsers.length > 0
                    ? () => Navigator.pop(context, [_selectedUsers, _groupName])
                    : null,
                child: Text('Create new channel')),
          )
        ]);
  }
}
