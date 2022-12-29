import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:social_media_app/apis/models/entities/chat_message.dart';
import 'package:social_media_app/apis/models/entities/online_user.dart';
import 'package:social_media_app/apis/models/responses/chat_message_list_response.dart';
import 'package:social_media_app/apis/providers/api_provider.dart';
import 'package:social_media_app/apis/providers/socket_api_provider.dart';
import 'package:social_media_app/app_services/auth_service.dart';
import 'package:social_media_app/constants/strings.dart';
import 'package:social_media_app/modules/home/controllers/profile_controller.dart';
import 'package:social_media_app/services/hive_service.dart';
import 'package:social_media_app/utils/utility.dart';

class ChatController extends GetxController {
  static ChatController get find => Get.find();

  final _auth = AuthService.find;
  final _apiProvider = ApiProvider(http.Client());
  final profile = ProfileController.find;
  final _socketApiProvider = SocketApiProvider();

  final _isLoading = false.obs;
  final _isMoreLoading = false.obs;
  final _lastMessageData = const ChatMessageListResponse().obs;

  // late SignalProtocolManager signalProtocolManager;
  final List<ChatMessage> _lastMessageList = [];
  final List<OnlineUser> _onlineUsers = [];
  final List<String> _typingUsers = [];

  /// Getters
  bool get isLoading => _isLoading.value;

  bool get isMoreLoading => _isMoreLoading.value;

  ChatMessageListResponse? get lastMessageData => _lastMessageData.value;

  List<ChatMessage> get lastMessageList => _lastMessageList;

  List<OnlineUser> get onlineUsers => _onlineUsers;

  List<String> get typingUsers => _typingUsers;

  StreamSubscription<dynamic>? _socketSubscription;

  /// Setters
  set setLastMessageData(ChatMessageListResponse response) =>
      _lastMessageData.value = response;

  Future<void> initialize() async {
    if (_socketApiProvider.isConnected) {
      _socketSubscription ??=
          _socketApiProvider.socketEventStream!.listen(_addSocketEventListener);
    }
    await _getLastMessages();
    _getUndeliveredMessages();
    _checkOnlineUsers();
  }

  Future<void> close() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    _lastMessageList.clear();
    _onlineUsers.clear();
    _typingUsers.clear();
    update();
    AppUtility.log("ChatController closed");
  }

  void _getUndeliveredMessages() {
    AppUtility.log('Get Undelivered Messages');
    _socketApiProvider.sendJson({
      'type': 'get-undelivered-messages',
    });
  }

  void _checkOnlineUsers() {
    AppUtility.log('Check Online Users');
    var userIds = _lastMessageList
        .map((e) => e.senderId == profile.profileDetails!.user!.id
            ? e.receiverId
            : e.senderId)
        .toList();

    _socketApiProvider.sendJson({
      'type': 'check-online-users',
      'payload': {
        'userIds': userIds,
      },
    });
  }

  void _addSocketEventListener(dynamic event) {
    var decodedData = jsonDecode(event);

    var type = decodedData['type'];
    AppUtility.log("Socket Event Type: $type");

    switch (type) {
      case 'connection':
        AppUtility.log("Socket Connected");
        break;

      case 'message':
        var chatMessage = ChatMessage.fromJson(decodedData['data']);
        _addMessageListener(chatMessage);
        break;

      case 'onlineStatus':
        var onlineUser = OnlineUser.fromJson(decodedData['data']);
        _addOnlineUserListener(onlineUser);
        break;

      case 'messageDelete':
        var messageId = decodedData['messageId'];
        _deleteMessageListener(messageId);
        break;

      case 'messageTyping':
        var userId = decodedData['data']['senderId'];
        var isTyping = decodedData['data']['status'];
        _addTypingIndicatorListener(userId, isTyping);
        break;

      case 'error':
        AppUtility.log("Error: ${decodedData['message']}");
        AppUtility.showSnackBar(decodedData['message'], StringValues.error);
        break;

      default:
        AppUtility.log("Invalid event type: $type");
        break;
    }
  }

  void _addTypingIndicatorListener(String userId, String status) {
    if (status == 'start') {
      _typingUsers.add(userId);
    } else {
      _typingUsers.remove(userId);
    }
    update();
  }

  void _addOnlineUserListener(OnlineUser onlineUser) {
    var status = onlineUser.status!;

    switch (status) {
      case 'online':
        _onlineUsers.add(onlineUser);
        update();
        break;

      case 'offline':
        _onlineUsers
            .removeWhere((element) => element.userId == onlineUser.userId);
        update();
        break;

      default:
        AppUtility.log("Invalid status: $status");
        break;
    }

    AppUtility.log('Online Users: ${_onlineUsers.length}');
  }

  void _addMessageListener(ChatMessage encryptedMessage) async {
    var isExitsInAllMessages =
        await _checkIfSameMessageInAllMessages(encryptedMessage);
    if (!isExitsInAllMessages) {
      await HiveService.put<ChatMessage>(
        'allMessages',
        encryptedMessage.id ?? encryptedMessage.tempId,
        encryptedMessage,
      );
    } else {
      var tempMessage = await HiveService.get<ChatMessage>(
          'allMessages', encryptedMessage.id ?? encryptedMessage.tempId);
      var updatedMessage = tempMessage!.copyWith(
        id: encryptedMessage.id,
        sender: encryptedMessage.sender,
        receiver: encryptedMessage.receiver,
        replyTo: encryptedMessage.replyTo,
        sent: encryptedMessage.sent,
        sentAt: encryptedMessage.sentAt,
        delivered: encryptedMessage.delivered,
        deliveredAt: encryptedMessage.deliveredAt,
        seen: encryptedMessage.seen,
        seenAt: encryptedMessage.seenAt,
        createdAt: encryptedMessage.createdAt,
        updatedAt: encryptedMessage.updatedAt,
      );
      await HiveService.delete<ChatMessage>(
        'allMessages',
        tempMessage.id ?? tempMessage.tempId,
      );
      await HiveService.put<ChatMessage>(
        'allMessages',
        updatedMessage.id ?? updatedMessage.tempId,
        updatedMessage,
      );
    }

    if (!_checkIfSameMessageInLastMessages(encryptedMessage)) {
      var index = _checkIfAlreadyPresentInLastMessages(encryptedMessage);
      if (index < 0) {
        _lastMessageList.add(encryptedMessage);
        update();
        await HiveService.put<ChatMessage>(
          'lastMessages',
          encryptedMessage.id ?? encryptedMessage.tempId,
          encryptedMessage,
        );
      } else {
        var oldMessage = _lastMessageList.elementAt(index);
        var isAfter =
            _checkIfLatestChatInLastMessages(oldMessage, encryptedMessage);
        if (isAfter) {
          _lastMessageList.remove(oldMessage);
          _lastMessageList.add(encryptedMessage);
          update();
          await HiveService.delete<ChatMessage>(
            'lastMessages',
            oldMessage.id ?? oldMessage.tempId,
          );
          await HiveService.put<ChatMessage>(
            'lastMessages',
            encryptedMessage.id ?? encryptedMessage.tempId,
            encryptedMessage,
          );
        }
      }
    } else {
      var tempIndex = _lastMessageList.indexWhere(
        (element) =>
            element.tempId == encryptedMessage.tempId ||
            element.id == encryptedMessage.id,
      );
      var tempMessage = _lastMessageList[tempIndex];
      var updatedMessage = tempMessage.copyWith(
        id: encryptedMessage.id,
        sender: encryptedMessage.sender,
        receiver: encryptedMessage.receiver,
        replyTo: encryptedMessage.replyTo,
        sent: encryptedMessage.sent,
        sentAt: encryptedMessage.sentAt,
        delivered: encryptedMessage.delivered,
        deliveredAt: encryptedMessage.deliveredAt,
        seen: encryptedMessage.seen,
        seenAt: encryptedMessage.seenAt,
        createdAt: encryptedMessage.createdAt,
        updatedAt: encryptedMessage.updatedAt,
      );
      _lastMessageList[tempIndex] = updatedMessage;
      update();
      await HiveService.delete<ChatMessage>('lastMessages', tempMessage.id!);
      await HiveService.put<ChatMessage>(
        'lastMessages',
        updatedMessage.id ?? updatedMessage.tempId,
        updatedMessage,
      );
    }
    AppUtility.log("Chat Message Added");
  }

  void _deleteMessageListener(String messageId) async {
    var indexInLastMessages =
        _lastMessageList.indexWhere((element) => element.id == messageId);

    if (indexInLastMessages >= 0) {
      _lastMessageList.removeAt(indexInLastMessages);
      update();
      await HiveService.delete<ChatMessage>('lastMessages', messageId);
    }

    var item = await HiveService.get<ChatMessage>('allMessages', messageId);

    if (item != null) {
      await HiveService.delete<ChatMessage>('allMessages', messageId);
    }

    AppUtility.log("Chat Message Deleted");
  }

  // void deleteMultipleMessages(List<String> messageIds) {
  //   _socketApiProvider.sendJson({
  //     'type': 'delete-messages',
  //     'payload': {
  //       'messageIds': messageIds,
  //     }
  //   });
  // }

  // void deleteMessage(String messageId) {
  //   _socketApiProvider.sendJson({
  //     'type': 'delete-message',
  //     'payload': {
  //       'messageId': messageId,
  //     }
  //   });
  // }

  // var secretKeys = await _e2eeService.getSecretKeys();
  // var regId = int.parse(
  //   String.fromCharCodes(base64Decode(secretKeys.registrationId)),
  // );
  // var identityKeyPairString = secretKeys.identityKeyPair;
  // var decodedIdentityKeyPair = base64Decode(identityKeyPairString);
  // var identityKeyPair =
  //     IdentityKeyPair.fromSerialized(decodedIdentityKeyPair);
  // var protocolStore = NxSignalProtocolStore(identityKeyPair, regId);
  // var preKeys = secretKeys.preKeys;
  // var serializedPreKeys = <PreKeyRecord>[];
  // for (var item in preKeys) {
  //   var decodedPreKey = base64Decode(item);
  //   var preKey = PreKeyRecord.fromBuffer(decodedPreKey);
  //   serializedPreKeys.add(preKey);
  // }
  // var signedPreKeyString = secretKeys.signedPreKey;
  // var decodedSignedPreKey = base64Decode(signedPreKeyString);
  // var signedPreKey = SignedPreKeyRecord.fromSerialized(decodedSignedPreKey);
  //
  // for (var item in serializedPreKeys) {
  //   await protocolStore.storePreKey(item.id, item);
  // }
  // await protocolStore.storeSignedPreKey(
  //   signedPreKey.id,
  //   signedPreKey,
  // );
  //

  bool isUserTyping(String userId) {
    return _typingUsers.contains(userId);
  }

  bool isUserOnline(String userId) {
    var user = _onlineUsers.any(
      (element) => element.userId == userId,
    );
    return user;
  }

  bool checkIfYourMessage(ChatMessage message) {
    var yourId = profile.profileDetails!.user!.id;

    if (message.senderId == yourId) {
      return true;
    }

    return false;
  }

  bool _checkIfSameMessageInLastMessages(ChatMessage message) {
    var item = _lastMessageList.any((element) =>
        element.id == message.id ||
        (element.tempId != null &&
            message.tempId != null &&
            element.tempId == message.tempId));

    if (item) return true;

    return false;
  }

  Future<bool> _checkIfSameMessageInAllMessages(ChatMessage message) async {
    var item = await HiveService.get<ChatMessage>(
        'allMessages', message.id ?? message.tempId);

    // var item = _allMessages.any((element) =>
    //     element.id == message.id ||
    //     (element.tempId != null &&
    //         message.tempId != null &&
    //         element.tempId == message.tempId));

    if (item != null) return true;

    return false;
  }

  int _checkIfAlreadyPresentInLastMessages(ChatMessage message) {
    var item = _lastMessageList.any((element) =>
        (element.senderId == message.senderId &&
            element.receiverId == message.receiverId) ||
        (element.senderId == message.receiverId &&
            element.receiverId == message.senderId));

    if (item) {
      var index = _lastMessageList.indexWhere((element) =>
          (element.senderId == message.senderId &&
              element.receiverId == message.receiverId) ||
          (element.senderId == message.receiverId &&
              element.receiverId == message.senderId));
      return index;
    }
    return -1;
  }

  bool _checkIfLatestChatInLastMessages(
      ChatMessage oldMessage, ChatMessage newMessage) {
    var isAfter = newMessage.createdAt!.isAfter(oldMessage.createdAt!);
    if (isAfter) return true;
    return false;
  }

  _getLastMessages() async {
    var isExists = await HiveService.hasLength<ChatMessage>('lastMessages');

    if (isExists) {
      var data = await HiveService.getAll<ChatMessage>('lastMessages');
      data.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
      _lastMessageList.clear();
      _lastMessageList.addAll(data.toList());
      update();
    }

    await _fetchLastMessages();
  }

  Future<void> _fetchLastMessages() async {
    _isLoading.value = true;
    update();

    try {
      final response = await _apiProvider.getAllLastMessages(_auth.token);

      if (response.isSuccessful) {
        final decodedData = response.data;
        setLastMessageData = ChatMessageListResponse.fromJson(decodedData);
        _lastMessageList.clear();
        _lastMessageList.addAll(_lastMessageData.value.results!);
        for (var item in _lastMessageList) {
          await HiveService.put<ChatMessage>(
            'lastMessages',
            item.id ?? item.tempId,
            item,
          );
        }
        _isLoading.value = false;
        update();
      } else {
        final decodedData = response.data;
        _isLoading.value = false;
        update();
        AppUtility.showSnackBar(
          decodedData[StringValues.message],
          StringValues.error,
        );
      }
    } catch (exc) {
      _isLoading.value = false;
      update();
      AppUtility.showSnackBar('Error: ${exc.toString()}', StringValues.error);
    }
  }

  Future<void> _loadMore({int? page}) async {
    _isMoreLoading.value = true;
    update();

    try {
      final response =
          await _apiProvider.getAllLastMessages(_auth.token, page: page);

      if (response.isSuccessful) {
        final decodedData = response.data;
        setLastMessageData = ChatMessageListResponse.fromJson(decodedData);
        _lastMessageList.addAll(_lastMessageData.value.results!);
        for (var item in _lastMessageData.value.results!) {
          await HiveService.put<ChatMessage>(
            'lastMessages',
            item.id ?? item.tempId,
            item,
          );
        }
        _isMoreLoading.value = false;
        update();
      } else {
        final decodedData = response.data;
        _isMoreLoading.value = false;
        update();
        AppUtility.showSnackBar(
          decodedData[StringValues.message],
          StringValues.error,
        );
      }
    } catch (exc) {
      _isLoading.value = false;
      update();
      AppUtility.showSnackBar('Error: ${exc.toString()}', StringValues.error);
    }
  }

  Future<void> fetchLastMessages() async => await _fetchLastMessages();

  Future<void> loadMore() async =>
      await _loadMore(page: _lastMessageData.value.currentPage! + 1);
}
