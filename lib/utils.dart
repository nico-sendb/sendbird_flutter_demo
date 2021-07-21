import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:sendbird_flutter_demo/main.dart';
import 'package:sendbird_sdk/sendbird_sdk.dart' as Sendbird;

Future<Sendbird.User> connect(String userId, {String? nickname = ''}) async {
  if (userId == '') {
    throw ("No user ID was provided.");
  }

  try {
    final user = await sendbird.connect(userId);
    final updatedNickname = nickname == ''
        ? user.nickname == ''
            ? userId
            : null
        : nickname;
    if (updatedNickname != null) {
      sendbird.updateCurrentUserInfo(nickname: updatedNickname);
    }
    return user;
  } catch (e) {
    log(e.toString());
    throw e;
  }
}

String getChannelTitleString(Sendbird.GroupChannel channel) {
  String title;
  if (channel.name != "" && channel.name != null) {
    title = channel.name!;
  } else {
    StringBuffer membersTitle = StringBuffer();
    membersTitle.write(channel.members[0].nickname);
    channel.members.skip(1).forEach((element) {
      membersTitle.write(' / ' + element.nickname);
    });
    title = membersTitle.toString();
  }
  return title;
}

Widget getChannelTitle(Sendbird.GroupChannel channel,
    {String? desc = '', TextStyle? fontStyle}) {
  return Text(getChannelTitleString(channel) + desc!,
      style: fontStyle != null
          ? fontStyle
          : TextStyle(
              fontWeight: channel.unreadMessageCount > 0
                  ? FontWeight.bold
                  : FontWeight.normal));
}

Widget getChannelListItemSubtitle(Sendbird.GroupChannel channel,
    {TextStyle? fontStyle}) {
  return Text('${channel.lastMessage?.message ?? ''}', style: fontStyle);
}

Widget getChannelThumbnail(Sendbird.GroupChannel channel, [double? size]) {
  return getAvatar(channel.coverUrl,
      fallbackIcon: Icon(
        Icons.chat_bubble,
        size: 24.0,
      ),
      size: size);
}

Widget getAvatar(String? imageUrl, {Icon? fallbackIcon, double? size}) {
  return Container(
    width: size ?? 40,
    height: size ?? 40,
    decoration: (imageUrl != null && imageUrl != "")
        ? BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
                image: NetworkImage(imageUrl), fit: BoxFit.cover))
        : null,
    child: (imageUrl == null || imageUrl == "") ? fallbackIcon : null,
  );
}

Widget getChatMessageUserAvatar(Sendbird.BaseMessage message,
    {double? size, Padding? lastPadding}) {
  if (message is Sendbird.AdminMessage) {
    return Text('');
  }

  return Column(children: [
    getAvatar(message.sender?.profileUrl,
        fallbackIcon: Icon(
          Icons.person,
          size: 24.0,
        )),
    Text(message.sender?.nickname ?? ''),
    if (lastPadding != null) lastPadding
  ]);
}

Widget getUnreadMessageCount(Sendbird.GroupChannel channel) {
  return channel.unreadMessageCount > 0
      ? Container(
          child: Text('${channel.unreadMessageCount}',
              style: TextStyle(color: Colors.white)),
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red),
          padding: EdgeInsets.all(10))
      : Container(child: Text(''), padding: EdgeInsets.all(10));
}

Widget? getTypingUsers(List<Sendbird.User>? users) {
  if (users == null || users.length == 0) {
    return null;
  }
  if (users.length == 1)
    return Text(
      '${users.first.nickname} is typing...',
      style: TextStyle(color: Colors.black54, fontSize: 12),
    );

  String typingUsersString = '';
  for (var i = 0; i < users.length; i++) {
    typingUsersString += '${users[i].nickname}, ';
  }
  return Text('$typingUsersString are typing...',
      style: TextStyle(color: Colors.black54, fontSize: 12));
}

List<ListTile> getMembersList(List<Sendbird.Member> members,
    {blockUser, unBlockUser, required String currentUserId}) {
  return members
      .map<ListTile>((member) => ListTile(
            leading: getAvatar(member.profileUrl,
                fallbackIcon: Icon(
                  Icons.person,
                  size: 24.0,
                )),
            title: Text(
                (member.nickname == '' ? '<No nickname>' : member.nickname) +
                    (member.userId == currentUserId ? ' (me)' : '')),
            subtitle: Text(member.userId),
            trailing: member.userId == currentUserId
                ? null
                : IconButton(
                    icon: member.isBlockedByMe
                        ? Icon(
                            Icons.voice_over_off,
                            color: Colors.red,
                          )
                        : Icon(
                            Icons.record_voice_over,
                            color: Colors.green,
                          ),
                    onPressed: () {
                      // block/unblock user
                      if (member.isBlockedByMe) {
                        unBlockUser(member.userId);
                      } else {
                        blockUser(member.userId);
                      }
                    },
                  ),
          ))
      .toList();
}
