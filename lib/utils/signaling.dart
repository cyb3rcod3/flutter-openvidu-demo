import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:flutter_openvidu_demo/utils/ApiClient.dart';
import 'package:flutter_openvidu_demo/utils/RequestConfig.dart';
import 'package:flutter_openvidu_demo/utils/rtc_ice_candidate.dart';

enum SignalingState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
  CallStateWaiting
}

class JsonConstants {
  static const String value = 'value';
  static const String params = 'params';
  static const String method = 'method';
  static const String id = 'id';
  static const String result = 'result';
  static const String iceCandidate = 'iceCandidate';
  static const String participantJoined = "participantJoined";
  static const String participantEvicted = "participantEvicted";
  static const String participantUnpublished = "participantUnpublished";
  static const String streamPropertyChanged = "streamPropertyChanged";
  static const String sendMessage = "sendMessage";
  static const String participantPublished = "participantPublished";
  static const String participantLeft = "participantLeft";
  static const String sessionId = "sessionId";
  static const String sdpAnswer = "sdpAnswer";
  static const String joinRoom = "joinRoom";
  static const String metadata = "metadata";
  static const String publishVideo = "publishVideo";
  static const String onIceCandidate = 'onIceCandidate';
  static const String receiveVideoFrom = 'receiveVideoFrom';
  static const String endpointName = 'endpointName';
  static const String senderConnectionId = 'senderConnectionId';
  static const String connectionId = 'connectionId';
  static const String leaveRoom = 'leaveRoom';
  static const String streams = 'streams';
}

class RemoteParticipant {
  RemoteParticipant({this.id, this.streamId, this.mediaStream, this.peerConnection, this.metadata});

  String id;
  String streamId;
  MediaStream mediaStream;
  RTCPeerConnection peerConnection;
  String metadata;
}

typedef void SignalingStateCallback(SignalingState state);
typedef void StreamStateCallback(MediaStream stream);
typedef void OtherEventCallback(dynamic event);


class Signaling {

  Signaling(this._url, this._secret, this._userName, this._iceServer):
    _iceServers = {
      'iceServers': [
        {
          'url': 'stun:$_iceServer',
          //'username': _turnUsername,
          //'credential': _turnCredential
        },
      ]
    };  // Signaling


  WebSocket _socket;
  String _url;
  String _secret;
  String token;
  String session;
  String _userName;
  String _iceServer;
  String _userId;
  String _endpointName;

  Map<String, dynamic> _iceServers = <String, dynamic>{};
  Map<String, RemoteParticipant> _participants = <String, RemoteParticipant>{};
  Map<String, String> _participantEndpoints = <String, String>{};
  Map<int, String> _idsReceiveVideo = <int, String>{};

  int _internalId = 1;
  int _idPublishVideo;
  int _idJoinRoom;

  Timer _timer;
  
  MediaStream _localStream;
  RTCPeerConnection _localPeerConnection;
  bool _localPeerConnectionHasRemoteDescription = false;

  SignalingStateCallback onStateChange;
  StreamStateCallback onLocalStream;
  StreamStateCallback onAddRemoteStream;
  StreamStateCallback onRemoveRemoteStream;

  OtherEventCallback onParticipantsRemove;
  OtherEventCallback onParticipantsJoined;
  OtherEventCallback onParticipantsStreamUpdate;
  OtherEventCallback onMessageReceive;
  OtherEventCallback onUserId;
  OtherEventCallback onSelfEvict;

  List<Map<String, dynamic>> _iceCandidatesParams = <Map<String, dynamic>>[];
  List _remoteAlreadyInRoomValues;

  bool _haveRemoteAlreadyInRoom = false;


  final Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  void updateInternalId() {
    _internalId++;
  }

  void close() {
    _localStream?.dispose();
    _localStream = null;
    _timer?.cancel();
    _sendJson(JsonConstants.leaveRoom, null);
    _localPeerConnection?.close();
    _participants.forEach((String id, RemoteParticipant remoteParticipant) {
      remoteParticipant.peerConnection?.close();
    });
    _participants.clear();
    _socket?.close();
  }

  void switchCamera() {
    if (_localStream != null) {
      _localStream.getVideoTracks()[0].switchCamera();
    }
  }
  void muteMic() {
    if (_localStream != null) {
      //_FIX_IT
      _localStream.getVideoTracks()[0].setMicrophoneMute(true);
    }
  }

  Future<dynamic> createWebRtcSession({String sessionId}) {
    final Map<String, dynamic> bodyMap = <String, dynamic>{'customSessionId': sessionId};
    final Map<String, dynamic> headersMap =
    <String, dynamic>{
      'Authorization': 'Basic ${base64Encode(utf8.encode('OPENVIDUAPP:$_secret'))}'
    };
    return ApiClient().request<Map<String, dynamic>>(Config(
      uri: Uri.parse('https://$_url/api/sessions'),
      headers: headersMap,
      body: RequestBody.json(bodyMap),
      method: RequestMethod.post,
      responseType: ResponseBody.json()
    )).then((Map<String, dynamic> jsonResponse) {
      print('◤◢◤◢◤◢◤◢◤◢◤ Create WebRTC session POST response: $jsonResponse ◤◢◤◢◤◢◤◢◤◢◤');
      session = jsonResponse['id'];
      return session;
    }).catchError((error) {
      //__FIX_IT_IF_ERROR_409
      session = sessionId;
      print('createWebRtcSession error: $error');
      return sessionId;
    });
  }

  Future<dynamic> createWebRtcToken({@required String sessionId, String role = 'PUBLISHER'}){
    final Map<String, dynamic> bodyMap =
    <String, dynamic>{'session': sessionId, 'role': role, 'data': ''};
    final Map<String, dynamic> headersMap =
    <String, dynamic>{
      'Authorization': 'Basic ${base64Encode(utf8.encode('OPENVIDUAPP:$_secret'))}'
    };
    return ApiClient().request<Map<String, dynamic>>(Config(
      uri: Uri.parse('https://$_url/api/tokens'),
      headers: headersMap,
      body: RequestBody.json(bodyMap),
      method: RequestMethod.post,
      responseType: ResponseBody.json()
    )).then((Map<String, dynamic> jsonResponse) {
      print('◤◢◤◢◤◢◤◢◤◢◤ Create WebRTC token POST response: $jsonResponse ◤◢◤◢◤◢◤◢◤◢◤');
      token = jsonResponse['token'];
      return token;
    });
  }


  Future<void> connect() async {
    try {
      _socket = await WebSocket.connect('wss://$_url/openvidu');

      if (this.onStateChange != null) {
        this.onStateChange(SignalingState.ConnectionOpen);
        print('◤◢◤◢◤◢◤◢◤◢◤ Socket connected <----> ◤◢◤◢◤◢◤◢◤◢◤');
      }

      _socket.listen((data) {
        this.onMessage(json.decode(data));
      }, onDone: () {
        if (this.onStateChange != null) {
          this.onStateChange(SignalingState.ConnectionClosed);
          print('◤◢◤◢◤◢◤◢◤◢◤ Socket disconnected <-/--> ◤◢◤◢◤◢◤◢◤◢◤');
        }
      });

      _createLocalPeerConnection().then((_) {
        _idJoinRoom = _sendJson(JsonConstants.joinRoom, {
          JsonConstants.metadata: '{\"clientData\": \"$_userName\"}',
          'secret': '',
          'platform': Platform.isAndroid ? 'Android' : 'iOS',
          // 'dataChannels': 'false',
          'session': session,
          'token': token,
        });
        _createLocalOffer();
      });

      _startPingTimer();

    }catch(e){
      print('◤◢!◤◢◤!◢◤◢!◤◢◤ connect error: $e ◤◢!◤◢◤!◢◤◢!◤◢◤');
      if(this.onStateChange != null){
        this.onStateChange(SignalingState.ConnectionError);
      }
    }
  }

  Future<void> onMessage(message) async {
    Map<String, dynamic> mapData = message;
    print('◤◢◤◢◤◢◤◢◤◢◤ onMessage_json_from_socket ---> | $message | ◤◢◤◢◤◢◤◢◤◢◤');
    if (mapData.containsKey(JsonConstants.result)) {
      if (mapData['id'] == _idPublishVideo) {
        _endpointName = mapData[JsonConstants.result]['id'];
            print('◤◢◤◢◤◢(_1_)◤◢◤◢◤ ');
      } else if (mapData['id'] == _idJoinRoom) {
        _createLocalOffer();//??????????????????????
        print('◤◢◤◢◤◢(_2_)◤◢◤◢◤ ');
      }
      handleResult(mapData[JsonConstants.result], mapData[JsonConstants.id]);
      print('◤◢◤◢◤◢(_3 - handleResult_)◤◢◤◢◤ ');
    } else {
      handleMethod(mapData);
      print('◤◢◤◢◤◢(_3 - handleMethod)◤◢◤◢◤ ');

    }
  }

  void handleResult(Map<String, dynamic> data, int id) {
    if (data.containsKey(JsonConstants.sdpAnswer)) {
      _saveAnswer(data, id);
    } else if (data.containsKey(JsonConstants.sessionId)) {
      if (data.containsKey(JsonConstants.value)) { // Join room reply
        List<dynamic> values = data[JsonConstants.value];
        _userId = data['id'];
        if (this.onUserId != null){
          this.onUserId(data['id']);
        }
        for (Map<String, dynamic> iceCandidate in _iceCandidatesParams) {
          iceCandidate[JsonConstants.endpointName] = data['endpointName'] ?? data['id'];
          iceCandidate[JsonConstants.id] = data['id'] ?? data['endpointName'];
          _sendJson(JsonConstants.onIceCandidate, iceCandidate);
        }
        if (values.length > 0) {
          _addParticipantsAlreadyInRoom(values);
        }
      }
    } else if (data.containsKey(JsonConstants.value)) {
      print('|◤◢◤◢◤pong|');
    } else {
      print('Unrecognized: $data');
    }
  }

  void handleMethod(Map<String, dynamic> data) {
    print('◤◢◤◢◤◢◤◢◤◢◤ HANDLE_METHOD ◤◢◤◢◤◢◤◢◤◢◤ : $data');
    if (data.containsKey(JsonConstants.params)) {
      Map<String, dynamic> params = data[JsonConstants.params];
      String method = data[JsonConstants.method];
      switch (method) {
        case JsonConstants.iceCandidate:
          _iceCandidateMethod(params);
          print('◤◢◤◢◤◢◤◢◤◢◤ iceCandidate: $params ◤◢◤◢◤◢◤◢◤◢◤');
          break;
        case JsonConstants.participantJoined:
          _participantJoinedMethod(params);
          print('◤◢◤◢◤◢◤◢◤◢◤ participantJoined: $params ◤◢◤◢◤◢◤◢◤◢◤');
          break;
        case JsonConstants.sendMessage:
          _messageReceive(params);
          print('◤◢◤◢◤◢◤◢◤◢◤ sendMessage: $params ◤◢◤◢◤◢◤◢◤◢◤');
          break;
        case JsonConstants.participantPublished:
          _participantPublishedMethod(params);
          print('◤◢◤◢◤◢◤◢◤◢◤ participantPublished: $params ◤◢◤◢◤◢◤◢◤◢◤');
          break;
        case JsonConstants.participantLeft:
          print('◤◢◤◢◤◢◤◢◤◢◤ participantLeft: $params ◤◢◤◢◤◢◤◢◤◢◤');
          break;
        case JsonConstants.participantEvicted:
          _participantLeftMethod(params);
          print('◤◢◤◢◤◢◤◢◤◢◤ participantEvicted: $params ◤◢◤◢◤◢◤◢◤◢◤');
          break;
        default:
          print('handleMethod: can\'t understand method: $method');
          break;
      }
    } else {
      print('handleMethod, no params');
    }
  }

  Future<void> _addParticipantsAlreadyInRoom(List<dynamic> values) async {
    for (Map<String, dynamic> value in values) {
      String _remoteParticipantId = value[JsonConstants.id];
      RemoteParticipant remoteParticipant = RemoteParticipant(id: _remoteParticipantId, metadata: value[JsonConstants.metadata]);
      if (value.containsKey(JsonConstants.streams)) {
        List<dynamic> streamsList = value[JsonConstants.streams];
        Map<String, dynamic> stream = streamsList?.first;
        if (stream != null && stream.containsKey(JsonConstants.id)) {
          remoteParticipant.streamId = stream[JsonConstants.id];
        }
      }
      _participants[_remoteParticipantId] = remoteParticipant;
      _createRemotePeerConnection(remoteParticipant).then((RTCPeerConnection remotePeerConnection) async {
        _receiveVideoFromParticipant(remoteParticipant);
      });
      if (this.onStateChange != null) {
        this.onStateChange(SignalingState.CallStateConnected);
      }
    }
  }

  void _participantJoinedMethod(Map<String, dynamic> params) {
    RemoteParticipant remoteParticipant = RemoteParticipant(id: params[JsonConstants.id], metadata: params[JsonConstants.metadata]);
    _participants[remoteParticipant.id] = remoteParticipant;
    this.onParticipantsJoined(remoteParticipant);
    _createRemotePeerConnection(remoteParticipant);
    if (this.onStateChange != null) {
      this.onStateChange(SignalingState.CallStateConnected);
    }
  }

  void _messageReceive(Map<String, dynamic> params) {
    print('_message $params');
    if (this.onMessageReceive != null){
      this.onMessageReceive(params);
    }
  }

  void sendMessage(List to, String signalType, dynamic data) {
    Map _msg = {
      'to': to,
      'data': data,
      'type': signalType
    };
    _sendJson(JsonConstants.sendMessage, {
      'message': jsonEncode(_msg)
    });
  }

  Future<void> _receiveVideoFromParticipant(RemoteParticipant remoteParticipant) async {
    if (remoteParticipant.peerConnection == null) {
      return;
    }
    try {
      RTCSessionDescription sessionDescription = await remoteParticipant.peerConnection.createOffer(_constraints);
      remoteParticipant.peerConnection.setLocalDescription(sessionDescription);
      int id = _sendJson(JsonConstants.receiveVideoFrom, {
        'sender': remoteParticipant.streamId ?? remoteParticipant.id,
        'sdpOffer': sessionDescription.sdp
      });
      _idsReceiveVideo[id] = remoteParticipant.id;
    } catch(e) {
      print(e.toString());
    }
  }

  void _participantLeftMethod(Map<String, dynamic> params) {
    String participantId = params['connectionId'];
    if (participantId == _userId) {
      this.onSelfEvict(_userId);
    }
    else if (_participants.containsKey(participantId)) {
      this.onParticipantsRemove(_participants[participantId]);
      _participants[participantId].peerConnection?.close();
      _participants.remove(participantId);
      if (_participants.length == 0) {
        if (this.onStateChange != null) {
          this.onStateChange(SignalingState.CallStateWaiting);
        }
      }
    }
  }

  void _iceCandidateMethod(Map<String, dynamic> params) {
    bool isLocal = params[JsonConstants.senderConnectionId] == _userId;
    _saveIceCandidate(params, params[JsonConstants.endpointName], params[JsonConstants.senderConnectionId], isLocal);
  }

  void _saveIceCandidate(Map<String, dynamic> params, String endpointName, String senderConnectionId, bool isLocal) {
    CustomRTCIceCandidate iceCandidate = CustomRTCIceCandidate(params['candidate'], params['sdpMid'], params['sdpMLineIndex'], endpointName);
    if (isLocal && _localPeerConnection != null) {
      _localPeerConnection.addCandidate(iceCandidate);
    } else if (_participants.containsKey(senderConnectionId)) {
      _participants[senderConnectionId].peerConnection.addCandidate(iceCandidate);
      _participantEndpoints[senderConnectionId] = endpointName;
    }
  }

  void _saveAnswer(Map<String, dynamic> data, int id) {
    RTCSessionDescription sessionDescription = RTCSessionDescription(data['sdpAnswer'], 'answer');
    if (!_localPeerConnectionHasRemoteDescription) {
      _localPeerConnection.setRemoteDescription(sessionDescription);
      _localPeerConnectionHasRemoteDescription = true;
    } else if (_idsReceiveVideo.containsKey(id)) {
      _participants[_idsReceiveVideo[id]].peerConnection.setRemoteDescription(sessionDescription);
    }
  }

  void _startPingTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      _sendJson('ping', {
        'interval': '3000'
      });
      print('|ping◤◢◤◢◤|');
    });
  }

  Future<MediaStream> createStream({isLocalStream = false}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '320',
          'minHeight': '240',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };
    MediaStream stream = await navigator.getUserMedia(mediaConstraints);
    if (isLocalStream && this.onLocalStream != null) {
      this.onLocalStream(stream);
    }
    return stream;
  }

  Future<void> _createLocalPeerConnection() async {
    _localStream = await createStream(isLocalStream: true);
    _localPeerConnection = await createPeerConnection(_iceServers, _constraints);
    _localPeerConnection.onSignalingState = ((state) {
      if (state == RTCSignalingState.RTCSignalingStateStable) {
        
      }
    });
    _localPeerConnection.onIceGatheringState = ((state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        if (_haveRemoteAlreadyInRoom) {
          _addParticipantsAlreadyInRoom(_remoteAlreadyInRoomValues);
          _remoteAlreadyInRoomValues.clear();
          _haveRemoteAlreadyInRoom = false;
        }
      }
    });
    _localPeerConnection.onIceCandidate = (candidate) {
      Map<String, dynamic> iceCandidateParams = {
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMlineIndex,
        'candidate': candidate.candidate,
      };
      if (_userId != null){
        iceCandidateParams[JsonConstants.endpointName] = _endpointName ?? _userId;
        _sendJson(JsonConstants.onIceCandidate, iceCandidateParams);
      } else {
        _iceCandidatesParams.add(iceCandidateParams);
      }
    };
    _localPeerConnection.addStream(_localStream);
  }

  Future<RTCPeerConnection> _createRemotePeerConnection(RemoteParticipant remoteParticipant) async {
    RTCPeerConnection remotePeerConnection = await createPeerConnection(_iceServers, _constraints);
    remotePeerConnection.onIceCandidate = (candidate) {
      Map<String, dynamic> iceCandidateParams = {
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMlineIndex,
        'endpointName': remoteParticipant.streamId ?? _participantEndpoints[remoteParticipant.id] ?? remoteParticipant.id,
        'candidate': candidate.candidate,
      };
      _sendJson(JsonConstants.onIceCandidate, iceCandidateParams);
    };

    remotePeerConnection.onAddStream = ((stream) {
      remoteParticipant.mediaStream = stream;
      if (this.onParticipantsStreamUpdate != null){
        this.onParticipantsStreamUpdate(remoteParticipant);
      }
      if (this.onAddRemoteStream != null){
        this.onAddRemoteStream(stream);
      }
    });

    remotePeerConnection.onSignalingState = ((state) {
      print('remotePeerConnection.onSignalingState: $state');
      /*
      if (state == RTCSignalingState.RTCSignalingStateStable) {
        //
      }
      */
    });

    remotePeerConnection.onIceGatheringState = ((state) {
      print('icestate: $state');
    });

    remotePeerConnection.onRemoveStream = (stream) {
      remoteParticipant.mediaStream = stream;
      if (this.onParticipantsStreamUpdate != null){
        this.onParticipantsStreamUpdate(remoteParticipant);
      }
      if(this.onRemoveRemoteStream != null){
        this.onRemoveRemoteStream(stream);
      }
    };

    remotePeerConnection.onDataChannel = (channel) {
      print('onDataChannel: $channel');
    };

    remoteParticipant.peerConnection = remotePeerConnection;
    return remotePeerConnection;
  }

  Future<void> _createLocalOffer() async {
    try {
      RTCSessionDescription s = await _localPeerConnection.createOffer(_constraints);
      await _localPeerConnection.setLocalDescription(s);
      _idPublishVideo = _sendJson(JsonConstants.publishVideo, {
        'audioOnly': 'false',
        'hasAudio': 'true',
        'doLoopback': 'false',
        'hasVideo': 'true',
        'audioActive': 'true',
        'videoActive': 'true',
        'typeOfVideo': 'CAMERA',
        'frameRate': '30',
        'videoDimensions': '{\"width\": 320, \"height\": 240}',
        'sdpOffer': s.sdp
      });
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _participantPublishedMethod(Map<String, dynamic> params) async {
    String _remoteParticipantId = params[JsonConstants.id];
    if (_participants.containsKey(_remoteParticipantId)) {
      RemoteParticipant remoteParticipantPublished = _participants[_remoteParticipantId];
      if (params.containsKey(JsonConstants.streams)) {
        List<dynamic> streamsList = params[JsonConstants.streams];
        Map<String, dynamic> stream = streamsList?.first;
        if (stream != null && stream.containsKey(JsonConstants.id)) {
          remoteParticipantPublished.streamId = stream[JsonConstants.id];
        }
      }
      if (remoteParticipantPublished.peerConnection != null){
        _receiveVideoFromParticipant(remoteParticipantPublished);
      } else {        
        _createRemotePeerConnection(remoteParticipantPublished).then((RTCPeerConnection remotePeerConnection) async {
          _receiveVideoFromParticipant(remoteParticipantPublished);
        });
        
      }
    }
  }

  int _sendJson(String method, Map<String, dynamic> params) {
    Map<String, dynamic> dict = <String, dynamic>{};
    dict[JsonConstants.method] = method;
    dict[JsonConstants.id] = _internalId;
    dict['jsonrpc'] = '2.0';
    if ((params?.length ?? 0) > 0) {
      dict[JsonConstants.params] = params;
    }
    updateInternalId();
    String jsonString = json.encode(dict);
    _socket?.add(jsonString);
    print('◤◢◤◢◤◢◤◢◤◢◤ send_json_to_socket ---> | $jsonString | ◤◢◤◢◤◢◤◢◤◢◤');
    return _internalId - 1;
  }

}
