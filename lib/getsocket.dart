library getsocket;

import 'src/html.dart' if (dart.library.io) 'src/io.dart';

class GetSocket extends BaseWebSocket {
  GetSocket(String url, String path, {Duration ping}) : super(url, path, ping: ping);
}
