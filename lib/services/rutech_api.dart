import 'dart:convert';
import 'package:http/http.dart' as http;

class RutechApi {
  RutechApi({String? baseUrl})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'RUTECH_API_URL',
            defaultValue: 'http://10.0.2.2:8000',
          );

  final String baseUrl;

  Future<List<Map<String, dynamic>>> agencias() async {
    final response = await http.get(Uri.parse('$baseUrl/agencias'));
    _validate(response);
    return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> clientes({
    String? agencia,
    String? prioridad,
  }) async {
    final params = <String, String>{
      if (agencia != null) 'agencia': agencia,
      if (prioridad != null) 'prioridad': prioridad,
    };
    final uri = Uri.parse(
      '$baseUrl/clientes',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    _validate(response);
    return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> planificar({
    required String agencia,
    int maxVisitas = 15,
  }) async {
    final uri = Uri.parse('$baseUrl/planificar').replace(
      queryParameters: {'agencia': agencia, 'max_visitas': '$maxVisitas'},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    _validate(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void _validate(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'El servidor respondió ${response.statusCode}: ${response.body}',
      );
    }
  }
}
