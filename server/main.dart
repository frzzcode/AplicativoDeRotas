import 'dart:convert';
import 'dart:io';

import 'google_routes.dart';

// Serviço de desenvolvimento local. A chave do Google nunca vai para o APK.
Future<void> main() async {
  final key = Platform.environment['GOOGLE_ROUTES_API_KEY'] ?? '';
  final token = Platform.environment['ROTAS_API_TOKEN'] ?? '';
  if (key.isEmpty || token.length < 24) {
    stderr.writeln(
      'Configure GOOGLE_ROUTES_API_KEY e ROTAS_API_TOKEN (mínimo 24 caracteres).',
    );
    exitCode = 1;
    return;
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  stdout.writeln(
    'Serviço de rotas em http://127.0.0.1:8080/rotas (use adb reverse no Android).',
  );
  var ocupado = false;
  await for (final request in server) {
    request.response.headers.contentType = ContentType.json;
    try {
      if (request.headers.value(HttpHeaders.authorizationHeader) !=
          'Bearer $token') {
        request.response.statusCode = 401;
        request.response.write(
          jsonEncode({'erro': 'Acesso ao serviço não autorizado.'}),
        );
      } else if (request.method != 'POST' || request.uri.path != '/rotas') {
        request.response.statusCode = 404;
      } else if (ocupado) {
        request.response.statusCode = 429;
      } else {
        ocupado = true;
        final bytes = <int>[];
        await for (final chunk in request.timeout(
          const Duration(seconds: 10),
        )) {
          bytes.addAll(chunk);
          if (bytes.length > 32768) {
            throw const FormatException('Pedido grande demais.');
          }
        }
        final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final resultado = await calcularGoogle(
          key,
          body['origem'] as String,
          (body['enderecos'] as List).cast<String>(),
          body['destino'] as int?,
        );
        request.response.write(jsonEncode(resultado));
      }
    } catch (e) {
      request.response.statusCode = 400;
      request.response.write(
        jsonEncode({
          'erro': e is FormatException || e is HttpException
              ? e.toString()
              : 'Falha ao calcular a rota. Verifique a conexão e os endereços.',
        }),
      );
    } finally {
      ocupado = false;
      await request.response.close();
    }
  }
}
