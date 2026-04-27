import 'package:flutter/material.dart';
import '../api/api_service.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _correoCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _ciCtl = TextEditingController();
  final _nombreCtl = TextEditingController();
  final _apellidosCtl = TextEditingController();
  
  DateTime? _fechaNac;
  bool _isLoading = false;

  void _register() async {
    if (_correoCtl.text.isEmpty || _passwordCtl.text.isEmpty || _ciCtl.text.isEmpty ||
        _nombreCtl.text.isEmpty || _apellidosCtl.text.isEmpty || _fechaNac == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Por favor completa todos los campos')));
      return;
    }

    setState(() => _isLoading = true);
    
    final data = {
      "Correo": _correoCtl.text,
      "Password": _passwordCtl.text,
      "CI": _ciCtl.text,
      "Nombre": _nombreCtl.text,
      "Apellidos": _apellidosCtl.text,
      "Fechanac": _fechaNac!.toIso8601String().split('T')[0] // Formato SQLAlchemy (YYYY-MM-DD)
    };

    try {
      await ApiService.registerConductor(data);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡Conductor registrado con éxito!')));
      Navigator.pop(context); // Volver al login
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _fechaNac) {
      setState(() {
        _fechaNac = picked;
      });
    }
  }

  Widget _buildTextField(String hint, TextEditingController ctl, {bool isObscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: ctl,
        obscureText: isObscure,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      appBar: AppBar(
        title: Text('Registro de Conductor', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                _buildTextField('Carnet de Identidad (CI)', _ciCtl),
                _buildTextField('Nombres', _nombreCtl),
                _buildTextField('Apellidos', _apellidosCtl),
                ListTile(
                  tileColor: Colors.black26,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(
                    _fechaNac == null ? 'Seleccionar Fecha de Nacimiento' : 'Fecha: ${_fechaNac!.toIso8601String().split('T')[0]}',
                    style: TextStyle(color: _fechaNac == null ? Colors.grey[400] : Colors.white),
                  ),
                  trailing: Icon(Icons.calendar_today, color: Colors.blueAccent),
                  onTap: () => _selectDate(context),
                ),
                SizedBox(height: 16),
                _buildTextField('Correo electrónico', _correoCtl),
                _buildTextField('Contraseña', _passwordCtl, isObscure: true),
                
                SizedBox(height: 32),
                _isLoading
                    ? CircularProgressIndicator(color: Colors.blueAccent)
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Registrarse',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
