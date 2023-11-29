// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:social_media_app/class/UserDataClass.dart';
import 'package:social_media_app/class/UserDataNotifier.dart';
import 'package:social_media_app/class/UserSocialClass.dart';
import 'package:social_media_app/class/UserSocialNotifier.dart';
import 'package:social_media_app/mixin/LifecycleListenerMixin.dart';
import 'package:social_media_app/redux/reduxLibrary.dart';
import 'package:social_media_app/styles/AppStyles.dart';
import 'package:social_media_app/appdata/GlobalLibrary.dart';
import 'custom/CustomPagination.dart';
import 'custom/CustomUserDataWidget.dart';
import 'streams/UserDataStreamClass.dart';

class ProfilePageFollowingWidget extends StatelessWidget {
  final String userID;
  const ProfilePageFollowingWidget({super.key, required this.userID});

  @override
  Widget build(BuildContext context) {
    return _ProfilePageFollowingWidgetStateful(userID: userID);
  }
}

class _ProfilePageFollowingWidgetStateful extends StatefulWidget {
  final String userID;
  const _ProfilePageFollowingWidgetStateful({required this.userID});

  @override
  State<_ProfilePageFollowingWidgetStateful> createState() => _ProfilePageFollowingWidgetStatefulState();
}

var dio = Dio();

class _ProfilePageFollowingWidgetStatefulState extends State<_ProfilePageFollowingWidgetStateful> with LifecycleListenerMixin{
  final ScrollController _scrollController = ScrollController();
  ValueNotifier<bool> displayFloatingBtn = ValueNotifier(true);
  late String userID;
  ValueNotifier<bool> isLoading = ValueNotifier(false);
  ValueNotifier<List<String>> users = ValueNotifier([]);
  ValueNotifier<LoadingStatus> loadingUsersStatus = ValueNotifier(LoadingStatus.loaded);
  ValueNotifier<bool> canPaginate = ValueNotifier(false);
  late StreamSubscription userDataStreamClassSubscription;

  @override
  void initState(){
    super.initState();
    userID = widget.userID;
    runDelay(() async => fetchProfileFollowing(users.value.length, false), actionDelayTime);
    userDataStreamClassSubscription = UserDataStreamClass().userDataStream.listen((UserDataStreamControllerClass data) {
      if(data.uniqueID == userID && data.actionType.name == UserDataStreamsUpdateType.addFollowing.name){
        if(mounted){
          if(!users.value.contains(data.userID)){
            users.value = [data.userID, ...users.value];
          }
        }
      }
    }); 
    _scrollController.addListener(() {
      if(mounted){
        if(_scrollController.position.pixels > animateToTopMinHeight){
          if(!displayFloatingBtn.value){
            displayFloatingBtn.value = true;
          }
        }else{
          if(displayFloatingBtn.value){
            displayFloatingBtn.value = false;
          }
        }
      }
    });
  }

  @override void dispose(){
    userDataStreamClassSubscription.cancel();
    super.dispose();
    _scrollController.dispose();
    displayFloatingBtn.dispose();
    isLoading.dispose();
    users.dispose();
    loadingUsersStatus.dispose();
    canPaginate.dispose();
  }

  Future<void> fetchProfileFollowing(int currentUsersLength, bool isRefreshing) async{
    try {
      if(mounted){
        isLoading.value = true;
        String stringified = jsonEncode({
          'userID': userID,
          'currentID': fetchReduxDatabase().currentID,
          'currentLength': currentUsersLength,
          'paginationLimit': usersPaginationLimit,
          'maxFetchLimit': usersServerFetchLimit
        });
        var res = await dio.get('$serverDomainAddress/users/fetchUserProfileFollowing', data: stringified);
        if(res.data.isNotEmpty){
          if(res.data['message'] == 'Successfully fetched data'){
            List userProfileDataList = res.data['usersProfileData'];
            List followingSocialsDatasList = res.data['usersSocialsData'];
            if(isRefreshing && mounted){
              users.value = [];
            }
            if(mounted){
              canPaginate.value = res.data['canPaginate'];
            }
            for(int i = 0; i < userProfileDataList.length; i++){
              Map userProfileData = userProfileDataList[i];
              UserDataClass userDataClass = UserDataClass.fromMap(userProfileData);
              UserSocialClass userSocialClass = UserSocialClass.fromMap(followingSocialsDatasList[i]);
              if(mounted){
                updateUserData(userDataClass, context);
                updateUserSocials(userDataClass, userSocialClass, context);
                users.value = [userProfileData['user_id'], ...users.value];
              }
            }
          }
          if(mounted){
            isLoading.value = false;
          }
        }
      }
    } on Exception catch (e) {
      doSomethingWithException(e);
    }
  }

  Future<void> loadMoreUsers() async{
    try {
      if(mounted){
        loadingUsersStatus.value = LoadingStatus.loading;
        Timer.periodic(const Duration(milliseconds: 1500), (Timer timer) async{
          timer.cancel();
          await fetchProfileFollowing(users.value.length, false);
          if(mounted){
            loadingUsersStatus.value = LoadingStatus.loaded;
          }
        });
      }
    } on Exception catch (e) {
      doSomethingWithException(e);
    }
  }

  @override
  Widget build(BuildContext context) {
     return Scaffold(
      appBar: AppBar(
        title: const Text('Following'), 
        titleSpacing: defaultAppBarTitleSpacing,
        flexibleSpace: Container(
          decoration: defaultAppBarDecoration
        )
      ),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: false,
            child: Builder(
              builder: (BuildContext context) {
                return StoreConnector<AppState, ValueNotifier<Map<String, UserDataNotifier>>>(
                  converter: (store) => store.state.usersDatasNotifiers,
                  builder: (context, ValueNotifier<Map<String, UserDataNotifier>> usersDatasNotifiers){
                    return StoreConnector<AppState, ValueNotifier<Map<String, UserSocialNotifier>>>(
                      converter: (store) => store.state.usersSocialsNotifiers,
                      builder: (context, ValueNotifier<Map<String, UserSocialNotifier>> usersSocialsNotifiers){
                        return ValueListenableBuilder(
                          valueListenable: loadingUsersStatus,
                          builder: (context, loadingStatusValue, child){
                            return ValueListenableBuilder(
                              valueListenable: canPaginate,
                              builder: (context, canPaginateValue, child){
                                return ValueListenableBuilder(
                                  valueListenable: users,
                                  builder: ((context, users, child) {
                                    return LoadMoreBottom(
                                      addBottomSpace: canPaginateValue,
                                      loadMore: () async{
                                        if(canPaginateValue){
                                          await loadMoreUsers();
                                        }
                                      },
                                      status: loadingStatusValue,
                                      refresh: null,
                                      child: CustomScrollView(
                                        controller: _scrollController,
                                        physics: const AlwaysScrollableScrollPhysics(),
                                        slivers: <Widget>[
                                          SliverList(delegate: SliverChildBuilderDelegate(
                                            childCount: users.length, 
                                            (context, index) {
                                              if(fetchReduxDatabase().usersDatasNotifiers.value[users[index]] != null){
                                                return ValueListenableBuilder(
                                                  valueListenable: fetchReduxDatabase().usersDatasNotifiers.value[users[index]]!.notifier, 
                                                  builder: ((context, userData, child) {
                                                    return ValueListenableBuilder(
                                                      valueListenable: fetchReduxDatabase().usersSocialsNotifiers.value[users[index]]!.notifier, 
                                                      builder: ((context, userSocial, child) {
                                                        return CustomUserDataWidget(
                                                          userData: userData,
                                                          userSocials: userSocial,
                                                          userDisplayType: UserDisplayType.following,
                                                          profilePageUserID: userID,
                                                          isLiked: null,
                                                          isBookmarked: null,
                                                          key: UniqueKey()
                                                        );
                                                      })
                                                    );
                                                  })
                                                );
                                              }
                                              return Container();  
                                            }
                                          ))                                    
                                        ]
                                      )
                                    );
                                  })
                                );
                              }
                            );
                          }
                        );
                      }
                    );
                  }
                );
              }
            )
          ),
          ValueListenableBuilder(
            valueListenable: isLoading,
            builder: ((context, isLoadingValue, child) {
              if(isLoadingValue){
                return loadingPageWidget();
              }
              return Container();
            })
          )
        ]
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: displayFloatingBtn,
        builder: (BuildContext context, bool visible, Widget? child) {
          return Visibility(
            visible: visible,
            child: FloatingActionButton( 
              heroTag: UniqueKey(),
              onPressed: () {  
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 10),
                  curve:Curves.fastOutSlowIn
                  );
              },
              child: const Icon(Icons.arrow_upward),
            )
          );
        }
      )
    );
  }
}