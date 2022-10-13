import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:social_media_app/apis/models/entities/follower.dart';
import 'package:social_media_app/apis/models/entities/user.dart';
import 'package:social_media_app/apis/models/responses/follower_response.dart';
import 'package:social_media_app/apis/providers/api_provider.dart';
import 'package:social_media_app/apis/services/auth_service.dart';
import 'package:social_media_app/constants/strings.dart';
import 'package:social_media_app/modules/home/controllers/profile_controller.dart';
import 'package:social_media_app/utils/utility.dart';

class FollowingListController extends GetxController {
  static FollowingListController get find => Get.find();

  final _auth = AuthService.find;
  final profile = ProfileController.find;

  final _apiProvider = ApiProvider(http.Client());

  final _followingData = const FollowerResponse().obs;
  final _isLoading = false.obs;
  final _isMoreLoading = false.obs;
  final _userId = ''.obs;
  final List<Follower> _followingList = [];

  final searchTextController = TextEditingController();

  /// Getters
  bool get isLoading => _isLoading.value;

  bool get isMoreLoading => _isMoreLoading.value;

  FollowerResponse? get followingData => _followingData.value;

  String? get userId => _userId.value;

  List<Follower> get followingList => _followingList;

  /// Setters
  set setFollowingListData(FollowerResponse value) {
    _followingData.value = value;
  }

  @override
  void onInit() async {
    _userId.value = Get.arguments;
    await _getFollowingList();
    super.onInit();
  }

  Future<void> _getFollowingList() async {
    AppUtility.printLog("Get Following List Request");

    if (_userId.value.isEmpty) {
      AppUtility.printLog("UserId not found");
      return;
    }

    _isLoading.value = true;
    update();

    try {
      final response = await _apiProvider.getFollowings(
        _auth.token,
        _userId.value,
      );

      final decodedData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        setFollowingListData = FollowerResponse.fromJson(decodedData);
        _followingList.clear();
        _followingList.addAll(_followingData.value.results!);
        _isLoading.value = false;
        update();
        AppUtility.printLog("Get Following List Success");
      } else {
        _isLoading.value = false;
        update();
        AppUtility.printLog("Get Following List Error");
        AppUtility.showSnackBar(
          decodedData[StringValues.message],
          StringValues.error,
        );
      }
    } on SocketException {
      _isLoading.value = false;
      update();
      AppUtility.printLog("Get Following List Error");
      AppUtility.printLog(StringValues.internetConnError);
      AppUtility.showSnackBar(
          StringValues.internetConnError, StringValues.error);
    } on TimeoutException {
      _isLoading.value = false;
      update();
      AppUtility.printLog("Get Following List Error");
      AppUtility.printLog(StringValues.connTimedOut);
      AppUtility.showSnackBar(StringValues.connTimedOut, StringValues.error);
    } on FormatException catch (e) {
      _isLoading.value = false;
      update();
      AppUtility.printLog("Get Following List Error");
      AppUtility.printLog(StringValues.formatExcError);
      AppUtility.printLog(e);
      AppUtility.showSnackBar(StringValues.errorOccurred, StringValues.error);
    } catch (exc) {
      _isLoading.value = false;
      update();
      AppUtility.printLog("Get Following List Error");
      AppUtility.printLog(StringValues.errorOccurred);
      AppUtility.printLog(exc);
      AppUtility.showSnackBar(StringValues.errorOccurred, StringValues.error);
    }
  }

  Future<void> _loadMore({int? page}) async {
    AppUtility.printLog("Get Following List Request");

    if (_userId.value.isEmpty) {
      AppUtility.printLog("UserId not found");
      return;
    }

    _isMoreLoading.value = true;
    update();

    try {
      final response = await _apiProvider.getFollowings(
        _auth.token,
        _userId.value,
        page: page,
      );

      final decodedData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        setFollowingListData = FollowerResponse.fromJson(decodedData);
        _followingList.addAll(_followingData.value.results!);
        _isMoreLoading.value = false;
        update();
        AppUtility.printLog("Get More Following List Success");
      } else {
        _isMoreLoading.value = false;
        update();
        AppUtility.printLog("Get More Following List Error");
        AppUtility.showSnackBar(
          decodedData[StringValues.message],
          StringValues.error,
        );
      }
    } on SocketException {
      _isMoreLoading.value = false;
      update();
      AppUtility.printLog("Get More Following List Error");
      AppUtility.printLog(StringValues.internetConnError);
      AppUtility.showSnackBar(
          StringValues.internetConnError, StringValues.error);
    } on TimeoutException {
      _isMoreLoading.value = false;
      update();
      AppUtility.printLog("Get More Following List Error");
      AppUtility.printLog(StringValues.connTimedOut);
      AppUtility.showSnackBar(StringValues.connTimedOut, StringValues.error);
    } on FormatException catch (e) {
      _isMoreLoading.value = false;
      update();
      AppUtility.printLog("Get More Following List Error");
      AppUtility.printLog(StringValues.formatExcError);
      AppUtility.printLog(e);
      AppUtility.showSnackBar(StringValues.errorOccurred, StringValues.error);
    } catch (exc) {
      _isMoreLoading.value = false;
      update();
      AppUtility.printLog("Get More Following List Error");
      AppUtility.printLog(StringValues.errorOccurred);
      AppUtility.printLog(exc);
      AppUtility.showSnackBar(StringValues.errorOccurred, StringValues.error);
    }
  }

  Future<void> _searchFollowings(String searchText) async {
    if (searchText.isEmpty) {
      await _getFollowingList();
      return;
    }

    AppUtility.printLog("Search Followings Request");
    _isLoading.value = true;
    update();

    try {
      final response = await _apiProvider.searchFollowings(
        _auth.token,
        _userId.value,
        searchText,
      );

      final decodedData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        setFollowingListData = FollowerResponse.fromJson(decodedData);
        _followingList.clear();
        _followingList.addAll(_followingData.value.results!);
        _isLoading.value = false;
        update();
        AppUtility.printLog("Search Followings Success");
      } else {
        _isLoading.value = false;
        update();
        AppUtility.printLog("Search Followings Error");
        AppUtility.showSnackBar(
          decodedData[StringValues.message],
          StringValues.error,
        );
      }
    } on SocketException {
      _isLoading.value = false;
      update();
      AppUtility.printLog("Search Followings Error");
      AppUtility.printLog(StringValues.internetConnError);
      AppUtility.showSnackBar(
          StringValues.internetConnError, StringValues.error);
    } on TimeoutException {
      _isLoading.value = false;
      update();
      AppUtility.printLog("Search Followings Error");
      AppUtility.printLog(StringValues.connTimedOut);
      AppUtility.showSnackBar(StringValues.connTimedOut, StringValues.error);
    } on FormatException catch (e) {
      _isLoading.value = false;
      update();
      AppUtility.printLog("Search Followings Error");
      AppUtility.printLog(StringValues.formatExcError);
      AppUtility.printLog(e);
      AppUtility.showSnackBar(StringValues.errorOccurred, StringValues.error);
    } catch (exc) {
      _isLoading.value = false;
      update();
      AppUtility.printLog("Search Followings Error");
      AppUtility.printLog(StringValues.errorOccurred);
      AppUtility.printLog(exc);
      AppUtility.showSnackBar(StringValues.errorOccurred, StringValues.error);
    }
  }

  void _toggleFollowUser(User user) {
    if (user.isPrivate) {
      if (user.followingStatus == "notFollowing") {
        user.followingStatus = "requested";
        update();
        return;
      }
      if (user.followingStatus == "requested") {
        user.followingStatus = "notFollowing";
        update();
        return;
      }
      if (user.followingStatus == "following") {
        user.followingStatus = "notFollowing";
        update();
        return;
      }
    } else {
      if (user.followingStatus == "notFollowing") {
        user.followingStatus = "following";
        update();
        profile.fetchProfileDetails(fetchPost: false);
        return;
      } else {
        user.followingStatus = "notFollowing";
        update();
        profile.fetchProfileDetails(fetchPost: false);
        return;
      }
    }
  }

  Future<void> _followUnfollowUser(User user) async {
    AppUtility.printLog("Follow/Unfollow User Request");
    _toggleFollowUser(user);

    try {
      final response =
          await _apiProvider.followUnfollowUser(_auth.token, user.id);

      final decodedData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        await profile.fetchProfileDetails(fetchPost: false);
        AppUtility.showSnackBar(
          decodedData[StringValues.message],
          StringValues.success,
          duration: 2,
        );
        AppUtility.printLog("Follow/Unfollow User Success");
      } else {
        _toggleFollowUser(user);
        AppUtility.showSnackBar(
          decodedData[StringValues.message],
          StringValues.error,
          duration: 2,
        );
        AppUtility.printLog("Follow/Unfollow User Error");
      }
    } on SocketException {
      _toggleFollowUser(user);
      AppUtility.printLog("Follow/Unfollow User Error");
      AppUtility.printLog(StringValues.internetConnError);
      AppUtility.showSnackBar(
          StringValues.internetConnError, StringValues.error);
    } on TimeoutException {
      _toggleFollowUser(user);
      AppUtility.printLog("Follow/Unfollow User Error");
      AppUtility.printLog(StringValues.connTimedOut);
      AppUtility.showSnackBar(StringValues.connTimedOut, StringValues.error);
    } on FormatException catch (e) {
      _toggleFollowUser(user);
      AppUtility.printLog("Follow/Unfollow User Error");
      AppUtility.printLog(StringValues.formatExcError);
      AppUtility.printLog(e);
      AppUtility.showSnackBar(StringValues.errorOccurred, StringValues.error);
    } catch (exc) {
      _toggleFollowUser(user);
      AppUtility.printLog("Follow/Unfollow User Error");
      AppUtility.printLog(StringValues.errorOccurred);
      AppUtility.printLog(exc);
      AppUtility.showSnackBar(StringValues.errorOccurred, StringValues.error);
    }
  }

  Future<void> _cancelFollowRequest(User user) async {
    AppUtility.printLog("Cancel Follow Request");
    _toggleFollowUser(user);

    try {
      final response =
          await _apiProvider.cancelFollowRequest(_auth.token, user.id);

      final decodedData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        AppUtility.showSnackBar(
          decodedData[StringValues.message],
          StringValues.success,
        );
        AppUtility.printLog("Cancel FollowRequest Success");
      } else {
        _toggleFollowUser(user);
        AppUtility.showSnackBar(
          decodedData[StringValues.message],
          StringValues.error,
        );
        AppUtility.printLog("Cancel FollowRequest Error");
      }
    } on SocketException {
      _toggleFollowUser(user);
      AppUtility.printLog("Cancel FollowRequest Error");
      AppUtility.printLog(StringValues.internetConnError);
      AppUtility.showSnackBar(
          StringValues.internetConnError, StringValues.error);
    } on TimeoutException {
      _toggleFollowUser(user);
      AppUtility.printLog("Cancel FollowRequest Error");
      AppUtility.printLog(StringValues.connTimedOut);
      AppUtility.showSnackBar(StringValues.connTimedOut, StringValues.error);
    } on FormatException catch (e) {
      _toggleFollowUser(user);
      AppUtility.printLog("Cancel FollowRequest Error");
      AppUtility.printLog(StringValues.formatExcError);
      AppUtility.printLog(e);
      AppUtility.showSnackBar(StringValues.errorOccurred, StringValues.error);
    } catch (exc) {
      _toggleFollowUser(user);
      AppUtility.printLog("Cancel FollowRequest Error");
      AppUtility.printLog(StringValues.errorOccurred);
      AppUtility.printLog(exc);
      AppUtility.showSnackBar(StringValues.errorOccurred, StringValues.error);
    }
  }

  Future<void> followUnfollowUser(User user) async =>
      await _followUnfollowUser(user);

  Future<void> cancelFollowRequest(User user) async =>
      await _cancelFollowRequest(user);

  Future<void> getFollowingList() async => await _getFollowingList();

  Future<void> loadMore() async =>
      await _loadMore(page: _followingData.value.currentPage! + 1);

  Future<void> searchFollowings(String searchText) async =>
      await _searchFollowings(searchText);
}
