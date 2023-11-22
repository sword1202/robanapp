import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:social_media_app/ProfilePage.dart';
import 'package:social_media_app/ViewCommentComments.dart';
import 'package:social_media_app/ViewPostComments.dart';
import 'package:social_media_app/appdata/GlobalLibrary.dart';
import 'package:social_media_app/class/CommentClass.dart';
import 'package:social_media_app/class/NotificationClass.dart';
import 'package:social_media_app/class/PostClass.dart';
import 'package:social_media_app/styles/AppStyles.dart';
import 'package:social_media_app/transition/RightToLeftTransition.dart';
import '../extenstions/StringEllipsis.dart';

var dio = Dio();

class CustomNotificationWidget extends StatefulWidget{
  final NotificationClass notificationClass;
  
  const CustomNotificationWidget({super.key, required this.notificationClass});

  @override
  State<CustomNotificationWidget> createState() =>_CustomNotificationWidgetState();
}

class _CustomNotificationWidgetState extends State<CustomNotificationWidget>{
  late NotificationClass notificationClass;

  @override
  void initState(){
    super.initState();
    notificationClass = widget.notificationClass;
  }

  @override void dispose(){
    super.dispose();
  }

  String generateNotificationText(){
    if(notificationClass.type == 'follow'){
      return '${notificationClass.senderName} has followed you';
    }else if(notificationClass.referencedPostType.isNotEmpty){
      if(notificationClass.type == 'tagged'){
        return '${notificationClass.senderName} has tagged you in a ${notificationClass.referencedPostType}';
      }else if(notificationClass.type == 'upload_comment'){
        return '${notificationClass.senderName} has commented to your ${notificationClass.parentPostType}';
      }else if(notificationClass.type == 'like'){
        return '${notificationClass.senderName} has liked your ${notificationClass.referencedPostType}';
      }else if(notificationClass.type == 'bookmark'){
        return '${notificationClass.senderName} has bookmarked your ${notificationClass.referencedPostType}';
      }
    }
    return '';
  }

  String generateNotificationDescription(){
    if(!notificationClass.postDeleted){
      if(notificationClass.referencedPostType.isNotEmpty){
        if(notificationClass.content.isNotEmpty){
          return notificationClass.content;
        }else{
          if(notificationClass.mediasDatas.isNotEmpty){
            return 'This ${notificationClass.referencedPostType} contains media';
          }
        }
      }
    }
    return '';
  }

  void notificationPressed(){
    if(!notificationClass.postDeleted){
      if(notificationClass.type == 'follow'){
        runDelay(() => Navigator.push(
          context,
          SliderRightToLeftRoute(
            page: ProfilePageWidget(userID: notificationClass.sender)
          )
        ), navigatorDelayTime);
      }else if(notificationClass.type == 'tagged' || notificationClass.type == 'upload_comment'){
        if(notificationClass.referencedPostType == 'post'){
          runDelay(() => Navigator.push(
            context,
            SliderRightToLeftRoute(
              page: ViewPostCommentsWidget(
                selectedPostData: PostClass(
                  notificationClass.referencedPostID, 'post', '', notificationClass.sender, '',
                  [], 0, false, 0, false, 0, false
                )
              )
            )
          ), navigatorDelayTime);
        }else if(notificationClass.referencedPostType == 'comment'){
          runDelay(() => Navigator.push(
            context,
            SliderRightToLeftRoute(
              page: ViewCommentCommentsWidget(
                selectedCommentData: CommentClass(
                  notificationClass.referencedPostID, 'comment', '', notificationClass.sender, '', 
                  [], 0, false, 0, false, 0, '', '', '', false
                )
              )
            )
          ), navigatorDelayTime);
        }
      }else if(notificationClass.referencedPostType == 'post'){
        runDelay(() => Navigator.push(
          context,
          SliderRightToLeftRoute(
            page: ViewPostCommentsWidget(
              selectedPostData: PostClass(
                notificationClass.referencedPostID, 'post', '', fetchReduxDatabase().currentID, '', 
                [], 0, false, 0, false, 0, false
              )
            )
          )
        ), navigatorDelayTime);
      }else if(notificationClass.referencedPostType == 'comment'){
        runDelay(() => Navigator.push(
          context,
          SliderRightToLeftRoute(
            page: ViewCommentCommentsWidget(
              selectedCommentData: CommentClass(
                notificationClass.referencedPostID, 'comment', '', fetchReduxDatabase().currentID, '', 
                [], 0, false, 0, false, 0, '', '', '', false
              )
            )
          )
        ), navigatorDelayTime);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String notificationDescription = generateNotificationDescription();
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.symmetric(horizontal: defaultHorizontalPadding / 2, vertical: defaultVerticalPadding / 2),
      color: Colors.transparent,
      child:Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (){
            notificationPressed();
          },
          splashFactory: InkRipple.splashFactory,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: defaultHorizontalPadding / 2, vertical: defaultVerticalPadding / 2),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: (){
                    runDelay(() => Navigator.push(
                      context,
                      SliderRightToLeftRoute(
                        page: ProfilePageWidget(userID: notificationClass.sender)
                      )
                    ), navigatorDelayTime);
                  },
                  child: Container(
                    width: getScreenWidth() * 0.1, height: getScreenWidth() * 0.1,
                    decoration: BoxDecoration(
                      border: Border.all(width: 2, color: Colors.white),
                      borderRadius: BorderRadius.circular(100),
                      image: DecorationImage(
                        image: NetworkImage(
                          notificationClass.senderProfilePicLink
                        ), fit: BoxFit.fill
                      )
                    ),
                  ),
                ),
                SizedBox(
                  width: getScreenWidth() * 0.025
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(generateNotificationText(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: defaultTextFontSize), softWrap: true),
                      SizedBox(height: notificationDescription.isNotEmpty ? getScreenHeight() * 0.003 : 0),
                      notificationDescription.isNotEmpty ? Text(StringEllipsis.convertToEllipsis(notificationDescription), maxLines: 3, overflow: TextOverflow.ellipsis) : Container(),
                      SizedBox(height: getScreenHeight() * 0.003),
                      Text(getTimeDifference(notificationClass.time), style: const TextStyle(fontSize: 13))
                    ],
                  ),
                )
              ],
            )
          )
        )
      )
    );
  }
}