import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Nota: 10.0.2.2 es el localhost equivalente para el emulador de Android.
  // Si corres de forma nativa en Windows, usar 127.0.0.1.
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<Map<String, dynamic>> registerConductor(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/registrar-conductor'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error de registro');
    }
  }

  static Future<String?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'username': email,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final token = body['access_token'];
      final role = body['role'];
      
      // Bloquear cualquier ingreso que no sea conductor
      if (role != 'Conductor') {
         throw Exception('Acceso Denegado. Solo Conductores pueden usar esta App.');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('role', role);
      return token;
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error de credenciales');
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('token');
  }

  // --- Endpoints de Vehículos ---
  static Future<List<dynamic>> getVehiculos() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.get(
      Uri.parse('$baseUrl/vehiculos/mis-vehiculos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al cargar vehículos');
    }
  }

  static Future<Map<String, dynamic>> addVehiculo(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.post(
      Uri.parse('$baseUrl/vehiculos/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al registrar vehículo');
    }
  }

  // --- Endpoints de Incidentes ---
  static Future<Map<String, dynamic>> reportarIncidente(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.post(
      Uri.parse('$baseUrl/incidentes/reportar'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al reportar incidente');
    }
  }

  // --- Endpoints de Gestión de Solicitudes ---
  static Future<List<dynamic>> getMisIncidentes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.get(
      Uri.parse('$baseUrl/incidentes/mis-incidentes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al cargar incidentes');
    }
  }

  static Future<List<dynamic>> getTalleresDisponibles(double? lat, double? lng) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    String url = '$baseUrl/incidentes/talleres-disponibles';
    if (lat != null && lng != null) {
      url += '?lat=$lat&lng=$lng';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al cargar talleres');
    }
  }

  static Future<Map<String, dynamic>> asignarTaller(int incidenteId, int tallerId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.patch(
      Uri.parse('$baseUrl/incidentes/$incidenteId/asignar-taller'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'taller_id': tallerId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al asignar taller');
    }
  }

  static Future<Map<String, dynamic>> cancelarIncidente(int incidenteId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.patch(
      Uri.parse('$baseUrl/incidentes/$incidenteId/cancelar'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al cancelar incidente');
    }
  }

  static Future<Map<String, dynamic>> solicitarCotizacion(int incidenteId, int tallerId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.post(
      Uri.parse('$baseUrl/incidentes/$incidenteId/solicitar-cotizacion'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'taller_id': tallerId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al solicitar cotización');
    }
  }

  static Future<Map<String, dynamic>> aceptarCotizacion(int cotizacionId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.post(
      Uri.parse('$baseUrl/incidentes/cotizaciones/$cotizacionId/aceptar'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al aceptar cotización');
    }
  }

  // --- Endpoints de Notificaciones ---
  static Future<void> updateFcmToken(String fcmToken) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) return; // No hacemos tracking si no hay user

    final response = await http.post(
      Uri.parse('$baseUrl/notificaciones/token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'fcm_token': fcmToken}),
    );

    if (response.statusCode != 200) {
      print('Warn: Error al subir FCM token al backend');
    }
  }

  static Future<List<dynamic>> getMisNotificaciones() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.get(
      Uri.parse('$baseUrl/notificaciones/mis-notificaciones'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al cargar notificaciones');
    }
  }

  static Future<void> marcarNotificacionLeida(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.post(
      Uri.parse('$baseUrl/notificaciones/estado/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al actualizar notificacion');
    }
  }

  // --- Endpoints de Perfil ---
  static Future<Map<String, dynamic>> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.get(
      Uri.parse('$baseUrl/profile/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al cargar perfil');
    }
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.put(
      Uri.parse('$baseUrl/profile/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al actualizar perfil');
    }
  }

  // --- Endpoints de Pagos ---
  static Future<String> createStripeCheckout(int incidenteId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.post(
      Uri.parse('$baseUrl/pagos/$incidenteId/stripe'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['checkout_url'];
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al crear sesión de pago');
    }
  }

  static Future<Map<String, dynamic>> registrarPagoDirecto(int incidenteId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.post(
      Uri.parse('$baseUrl/pagos/$incidenteId/directo'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al registrar pago directo');
    }
  }

  static Future<Map<String, dynamic>> reintentarAnalisis(int incidenteId, String nuevaDescripcion) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) throw Exception('No autenticado');

    final response = await http.post(
      Uri.parse('$baseUrl/incidentes/$incidenteId/reintentar-analisis'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'nueva_descripcion': nuevaDescripcion}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al reintentar análisis');
    }
  }
}
