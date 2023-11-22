// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:social_media_app/class/UserDataClass.dart';
import 'package:social_media_app/mixin/LifecycleListenerMixin.dart';
import 'package:social_media_app/redux/reduxLibrary.dart';
import 'package:social_media_app/socket/main.dart';
import 'package:social_media_app/styles/AppStyles.dart';
import 'package:uuid/uuid.dart';
import 'package:social_media_app/appdata/GlobalLibrary.dart';
import 'class/GroupProfileClass.dart';
import 'class/UserDataNotifier.dart';
import 'custom/CustomButton.dart';
import 'custom/CustomSimpleUserDataWidget.dart';

var dio = Dio();

class AddUsersToGroupWidget extends StatelessWidget {
  final String chatID;
  final GroupProfileClass groupProfileData;
  const AddUsersToGroupWidget({super.key, required this.chatID, required this.groupProfileData});

  @override
  Widget build(BuildContext context) {
    return _AddUsersToGroupWidgetStateful(chatID: chatID, groupProfileData: groupProfileData);
  }
}

class _AddUsersToGroupWidgetStateful extends StatefulWidget {
  final String chatID;
  final GroupProfileClass groupProfileData;
  const _AddUsersToGroupWidgetStateful({required this.chatID, required this.groupProfileData});

  @override
  State<_AddUsersToGroupWidgetStateful> createState() => _AddUsersToGroupWidgetStatefulState();
}

class _AddUsersToGroupWidgetStatefulState extends State<_AddUsersToGroupWidgetStateful> with LifecycleListenerMixin{
  late String chatID;
  late ValueNotifier<GroupProfileClass> groupProfile;
  TextEditingController searchedController = TextEditingController();
  ValueNotifier<bool> isSearching = ValueNotifier(false);
  ValueNotifier<List<String>> users = ValueNotifier([]);
  ValueNotifier<List<String>> selectedUsersID = ValueNotifier([]);
  ValueNotifier<List<String>> selectedUsersName = ValueNotifier([]);
  ValueNotifier<bool> verifySearchedFormat = ValueNotifier(false);
  int groupMembersMaxLimit = 30;

  @override
  void initState(){
    super.initState();
    chatID = widget.chatID;
    groupProfile = ValueNotifier(widget.groupProfileData);
    searchedController.addListener(() {
      if(mounted){
        verifySearchedFormat.value = searchedController.text.isNotEmpty;
      }
    });
    socket.on("send-leave-group-announcement-$chatID", ( data ) async{
      if(mounted && data != null){
        groupProfile.value = GroupProfileClass(
          groupProfile.value.name, groupProfile.value.profilePicLink, 
          groupProfile.value.description, List<String>.of(data['recipients'])
        );
      }
    });
    socket.on("send-add-users-to-group-announcement-$chatID", ( data ) async{
      if(mounted && data != null){
        groupProfile.value = GroupProfileClass(
          groupProfile.value.name, groupProfile.value.profilePicLink, 
          groupProfile.value.description, List<String>.of([...data['recipients'], ...data['addedUsersID']])
        );
      }
    });
  }
 
  @override void dispose(){
    super.dispose();
    groupProfile.dispose();
    searchedController.dispose();
    isSearching.dispose();
    users.dispose();
    selectedUsersID.dispose();
    selectedUsersName.dispose();
    verifySearchedFormat.dispose();
    groupProfile.dispose();
  }

  Future<void> searchUsers(bool isPaginating) async{
    try {
      if(mounted){
        isSearching.value = true;
        String stringified = jsonEncode({
          'searchedText': searchedController.text,
          'recipients': groupProfile.value.recipients,
          'currentID': fetchReduxDatabase().currentID,
          'currentLength': isPaginating ? users.value.length : 0,
          'paginationLimit': searchTagUsersFetchLimit
        });
        var res = await dio.get('$serverDomainAddress/users/fetchSearchedAddToGroupUsers', data: stringified);
        if(res.data.isNotEmpty){
          if(res.data['message'] == 'Successfully fetched data'){
            List userProfileDataList = res.data['usersProfileData'];
            if(mounted){
              users.value = [];
            }
            for(int i = 0; i < userProfileDataList.length; i++){
              Map userProfileData = userProfileDataList[i];
              UserDataClass userDataClass = UserDataClass.fromMap(userProfileData);
              if(mounted){
                updateUserData(userDataClass, context);
                users.value = [...users.value, userProfileData['user_id']];
              }
            }
          }
          if(mounted){
            isSearching.value = false;
          }
        }
      }
    } on Exception catch (e) {
      doSomethingWithException(e);
    }
  }

  void toggleSelectUser(userID, name){
    if(mounted){
      List<String> selectedUsersIDList = [...selectedUsersID.value];
      if(selectedUsersIDList.contains(userID)){
        selectedUsersIDList.remove(userID);
        selectedUsersName.value.remove(name);
      }else{
        selectedUsersIDList.add(userID);
        selectedUsersName.value.add(name);
      }
      selectedUsersID.value = [...selectedUsersIDList];
    }
  }

  void addUsersToGroup() async{
    try {
      Navigator.pop(context);
      if(selectedUsersID.value.length + groupProfile.value.recipients.length > groupMembersMaxLimit){
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Alert!!!', style: TextStyle(fontSize: defaultTextFontSize)),
              content: SingleChildScrollView(
                child: ListBody(
                  children: [
                    Text('Failed to add user(s). Only a maximum of $groupMembersMaxLimit members are allowed for a group chat.', style: TextStyle(fontSize: defaultTextFontSize)),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Ok', style: TextStyle(fontSize: defaultTextFontSize)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }else{
        List<String> messagesID = List.filled(selectedUsersName.value.length, 0).map((e) => const Uuid().v4()).toList();
        String senderName = fetchReduxDatabase().usersDatasNotifiers.value[fetchReduxDatabase().currentID]!.notifier.value.name;
        List<String> contentsList = selectedUsersName.value.map((e) => '$senderName has added $e to the group').toList();
        List<Map> addedUsersDataList = [];
        for(int i = 0; i < selectedUsersID.value.length; i++){
          addedUsersDataList.add(fetchReduxDatabase().usersDatasNotifiers.value[selectedUsersID.value[i]]!.notifier.value.toMap());
        }
        socket.emit("add-users-to-group-to-server", {
          'chatID': chatID,
          'messagesID': messagesID,
          'contentsList': contentsList,
          'type': 'add_users_to_group',
          'sender': fetchReduxDatabase().currentID,
          'recipients': groupProfile.value.recipients,
          'mediasDatas': [],
          'addedUsersID': selectedUsersID.value,
          'groupProfileData': {
            'name': groupProfile.value.name,
            'profilePicLink': groupProfile.value.profilePicLink,
            'description': groupProfile.value.description
          },
          'addedUsersData': addedUsersDataList
        });
      
        String stringified = jsonEncode({
          'chatID': chatID,
          'messagesID': messagesID,
          'sender': fetchReduxDatabase().currentID,
          'recipients': groupProfile.value.recipients,
          'addedUsersID': selectedUsersID.value,
          
        });
        var res = await dio.patch('$serverDomainAddress/users/addUsersToGroup', data: stringified);
        if(res.data.isNotEmpty){
        }
      }
    } on Exception catch (e) {
      doSomethingWithException(e);
    }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Users'), 
        titleSpacing: defaultAppBarTitleSpacing,
        flexibleSpace: Container(
          decoration: defaultAppBarDecoration
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable: selectedUsersID,
            builder: (context, selectedUsersID, child){
              return CustomButton(
                width: getScreenWidth() * 0.25, height: kToolbarHeight, 
                buttonColor: Colors.red, buttonText: 'Continue',
                onTapped: selectedUsersID.isNotEmpty ? () => addUsersToGroup() : null,
                setBorderRadius: false,
              );
            }
          )
        ]
      ),
      body: ListView(
        children: [
          containerMargin(
            Row(
              children: [
                SizedBox(
                  width: getScreenWidth() * 0.75,
                  height: getScreenHeight() * 0.075,
                  child: TextField(
                    controller: searchedController,
                    decoration: generateSearchTextFieldDecoration('user'),
                  )
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: isSearching,
                  builder: (context, bool isSearchingValue, child){
                    return ValueListenableBuilder<bool>(
                      valueListenable: verifySearchedFormat,
                      builder: (context, bool searchedVerified, child){
                        return CustomButton(
                          width: getScreenWidth() * 0.25, height: getScreenHeight() * 0.075, 
                          buttonColor: Colors.red, buttonText: 'Search',
                          onTapped: !isSearchingValue && searchedVerified ? () => searchUsers(false) : null,
                          setBorderRadius: false,
                        );
                      }
                    );
                  }
                )
              ],
            ),
            EdgeInsets.symmetric(vertical: defaultTextFieldVerticalMargin)
          ),
          StoreConnector<AppState, ValueNotifier<Map<String, UserDataNotifier>>>(
            converter: (store) => store.state.usersDatasNotifiers,
            builder: (context, ValueNotifier<Map<String, UserDataNotifier>> usersDatasNotifiers){
              return ValueListenableBuilder(
                valueListenable: users, 
                builder: (context, users, child){
                  return ValueListenableBuilder(
                    valueListenable: selectedUsersID, 
                    builder: (context2, selectedUsersID, child2){
                      return Column(
                        children: [
                          for(int i = 0; i < users.length; i++)
                          InkWell(
                            splashFactory: InkRipple.splashFactory,
                            onTap: (){
                            },
                            child: GestureDetector(
                              onTap: (){
                                toggleSelectUser(users[i], usersDatasNotifiers.value[users[i]]!.notifier.value.name);
                              },
                              child: Container(
                                color: selectedUsersID.contains(users[i]) ? Colors.white.withOpacity(0.5) : Colors.transparent,
                                child: CustomSimpleUserDataWidget(
                                  userData: usersDatasNotifiers.value[users[i]]!.notifier.value,
                                  key: UniqueKey()
                                )
                              )
                            )
                          )
                        ],
                      );
                    }
                  );
                }
              );
            }
          )
        ],
      ),
    );
  }
}