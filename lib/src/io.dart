import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'dart:math';

import 'socket_notifier.dart';

enum ConnectionStatus {
  connecting,
  connected,
  closed,
}

class BaseWebSocket {
  String url;
  String path;
  WebSocket socket;
  SocketNotifier socketNotifier = SocketNotifier();
  bool isDisposed = false;
  BaseWebSocket(this.url, this.path, {this.ping = const Duration(seconds: 5)});
  Duration ping;
  bool allowSelfSigned = true;

  ConnectionStatus connectionStatus;

  Future connect() async {
    if (isDisposed) {
      socketNotifier = SocketNotifier();
    }
    try {
      connectionStatus = ConnectionStatus.connecting;
      socket = allowSelfSigned
          ? await _connectForSelfSignedCert(url, path)
          : await WebSocket.connect(url);

      socket.pingInterval = ping;
      socketNotifier?.open();
      connectionStatus = ConnectionStatus.connected;

      socket.listen((data) {
        socketNotifier.notifyData(data);
      }, onError: (err) {
        socketNotifier.notifyError(Close(err.toString(), 1005));
      }, onDone: () {
        connectionStatus = ConnectionStatus.closed;
        socketNotifier
            .notifyClose(Close('Connection Closed', socket.closeCode));
      }, cancelOnError: true);
      return;
    } on SocketException catch (e) {
      connectionStatus = ConnectionStatus.closed;
      socketNotifier.notifyError(Close(e.osError.message, e.osError.errorCode));
      return;
    }
  }

  void onOpen(OpenSocket fn) {
    socketNotifier.open = fn;
  }

  void onClose(CloseSocket fn) {
    socketNotifier.addCloses(fn);
  }

  void onError(CloseSocket fn) {
    socketNotifier.addErrors(fn);
  }

  void onMessage(MessageSocket fn) {
    socketNotifier.addMessages(fn);
  }

  void on(String event, MessageSocket message) {
    socketNotifier.addEvents(event, message);
  }

  void close([int status, String reason]) {
    if (socket != null) {
      socket.close(status, reason);
    }
  }

  void send(dynamic data) async {
    print(connectionStatus);
    if (connectionStatus == ConnectionStatus.closed) {
      await connect();
    }

    if (socket != null) {
      socket.add(data);
    }
  }

  void dispose() {
    socketNotifier.dispose();
    socketNotifier = null;
    isDisposed = true;
  }

  void emit(String event, dynamic data) {
    send(jsonEncode({'type': event, 'data': data}));
  }

  Future<WebSocket> _connectForSelfSignedCert(url, path) async {
    try {
      var r = Random();
      var key = base64.encode(List<int>.generate(8, (_) => r.nextInt(255)));
      var client = HttpClient();

      var request = await client.getUrl(Uri.parse(url + path));
      request.headers.add('Connection', 'Upgrade');
      request.headers.add('Upgrade', 'websocket');
      request.headers.add('Sec-WebSocket-Version', '13');
      request.headers.add('Sec-WebSocket-Key', key.toLowerCase());

      var response = await request.close();
      // ignore: close_sinks
      var socket = await response.detachSocket();
      var webSocket = WebSocket.fromUpgradedSocket(
        socket,
        protocol: 'signaling',
        serverSide: false,
      );

      return webSocket;
    } catch (e) {
      print(e);
      rethrow;
    }
  }
}
