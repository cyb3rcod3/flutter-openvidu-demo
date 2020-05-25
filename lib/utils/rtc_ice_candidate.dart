import 'package:flutter_webrtc/webrtc.dart';
class CustomRTCIceCandidate extends RTCIceCandidate {
  String candidate;
  String sdpMid;
  int sdpMlineIndex;
  String endpointName;

  CustomRTCIceCandidate(this.candidate, this.sdpMid, this.sdpMlineIndex, this.endpointName) : super('', '', 0);

  dynamic toMap() {
    return {
      "candidate": candidate,
      "sdpMid": sdpMid,
      "sdpMLineIndex": sdpMlineIndex,
      "endpointName": endpointName,
    };
  }
}
