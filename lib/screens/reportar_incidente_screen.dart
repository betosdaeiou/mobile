import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../api/api_service.dart';
import 'estado_incidente_screen.dart';

class ReportarIncidenteScreen extends StatefulWidget {
  final List<dynamic> vehiculosRegistrados;
  final LatLng? gpsReal;

  const ReportarIncidenteScreen({Key? key, required this.vehiculosRegistrados, this.gpsReal}) : super(key: key);

  @override
  _ReportarIncidenteScreenState createState() => _ReportarIncidenteScreenState();
}

class _ReportarIncidenteScreenState extends State<ReportarIncidenteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  int? _vehiculoSeleccionadoId;
  bool _isLoading = false;
  final List<File> _imagenes = [];
  static const int _maxImagenes = 10;

  // Audio Recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _audioPath;
  bool _isRecording = false;
  String _audioBase64 = "";

  Future<void> _tomarFoto() async {
    if (_imagenes.length >= _maxImagenes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Máximo $_maxImagenes imágenes permitidas'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final XFile? foto = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      maxHeight: 960,
      imageQuality: 75,
    );

    if (foto != null) {
      setState(() {
        _imagenes.add(File(foto.path));
      });
    }
  }

  Future<void> _seleccionarGaleria() async {
    final espacioDisponible = _maxImagenes - _imagenes.length;
    if (espacioDisponible <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Máximo $_maxImagenes imágenes permitidas'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final List<XFile> fotos = await _picker.pickMultiImage(
      maxWidth: 1280,
      maxHeight: 960,
      imageQuality: 75,
    );

    if (fotos.isNotEmpty) {
      final agregar = fotos.take(espacioDisponible).map((f) => File(f.path)).toList();
      setState(() {
        _imagenes.addAll(agregar);
      });

      if (fotos.length > espacioDisponible) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Solo se agregaron $espacioDisponible de ${fotos.length} imágenes (límite: $_maxImagenes)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _eliminarImagen(int index) {
    setState(() {
      _imagenes.removeAt(index);
    });
  }

  void _verImagenCompleta(File imagen) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.file(imagen),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _imagenesABase64() {
    if (_imagenes.isEmpty) return "";
    
    final List<String> base64List = [];
    for (final img in _imagenes) {
      final bytes = img.readAsBytesSync();
      base64List.add(base64Encode(bytes));
    }
    // Separamos con ||| para poder reconstruirlas en el backend
    return base64List.join('|||');
  }

  // --- AUDIO RECORDING METHODS ---
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/incidente_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        const config = RecordConfig();
        await _audioRecorder.start(config, path: path);

        setState(() {
          _isRecording = true;
          _audioPath = path;
        });
      }
    } catch (e) {
      print("Error al iniciar grabación: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        final bytes = await File(path).readAsBytes();
        setState(() {
          _isRecording = false;
          _audioBase64 = base64Encode(bytes);
          _audioPath = path;
        });
      }
    } catch (e) {
      print("Error al detener grabación: $e");
    }
  }

  void _eliminarAudio() {
    setState(() {
      _audioPath = null;
      _audioBase64 = "";
    });
  }

  Future<void> _submitIncidente() async {
    if (_vehiculoSeleccionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un vehículo')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final fotosEncoded = _imagenesABase64();

        final payload = {
          "coordenadagps": widget.gpsReal != null ? "${widget.gpsReal!.latitude}, ${widget.gpsReal!.longitude}" : "-17.78111, -63.18123",
          "estado": "Reportado",
          "vehiculo_id": _vehiculoSeleccionadoId,
          "evidencia": {
            "descripcion": _descripcionController.text.trim(),
            "fotos": fotosEncoded,
            "audio": _audioBase64
          }
        };

        final resultado = await ApiService.reportarIncidente(payload);
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EstadoIncidenteScreen(
                incidente: resultado,
                gpsReal: widget.gpsReal,
              ),
            ),
          );
        }
      } catch (e) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error al reportar'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              )
            ],
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Agregar Evidencia Fotográfica',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                '${_imagenes.length}/$_maxImagenes imágenes',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.blue, size: 26),
                ),
                title: const Text('Tomar Foto', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Usar la cámara del dispositivo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _tomarFoto();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.green, size: 26),
                ),
                title: const Text('Elegir de Galería', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Seleccionar múltiples imágenes'),
                onTap: () {
                  Navigator.pop(ctx);
                  _seleccionarGaleria();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay vehículos, no se puede reportar un accidente asociado a uno
    if (widget.vehiculosRegistrados.isEmpty) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.red[900], title: const Text('Reportar Emergencia')),
        body: const Center(child: Text("Debes registrar al menos un vehículo antes de reportar.")),
      );
    }

    return Scaffold(
        appBar: AppBar(
          title: const Text('Reportar Emergencia', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red[900],
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
            child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.warning_rounded, color: Colors.orange, size: 80),
                const SizedBox(height: 16),
                const Text(
                  'Mantén la calma.\nNuestros mecánicos estarán contigo pronto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                
                // --- SELECCION DE VEHICULO ---
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Vehículo Afectado',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_car),
                  ),
                  value: _vehiculoSeleccionadoId,
                  items: widget.vehiculosRegistrados.map((v) {
                    return DropdownMenuItem<int>(
                      value: v['Id'],
                      child: Text('${v['Marca']} ${v['Modelo']} - ${v['Placa']}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _vehiculoSeleccionadoId = val;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // --- DESCRIPCION EVENTO ---
                TextFormField(
                  controller: _descripcionController,
                  decoration: const InputDecoration(
                    labelText: '¿Qué sucedió? (Descripción)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  validator: (v) => v!.isEmpty ? 'Por favor ingresa una descripción' : null,
                ),
                const SizedBox(height: 20),

                // --- EVIDENCIA FOTOGRÁFICA ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.photo_camera, color: Colors.indigo, size: 22),
                          const SizedBox(width: 8),
                          const Text('Evidencia Fotográfica',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _imagenes.length >= _maxImagenes
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.indigo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_imagenes.length}/$_maxImagenes',
                              style: TextStyle(
                                color: _imagenes.length >= _maxImagenes ? Colors.red : Colors.indigo,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Grid de imágenes
                      if (_imagenes.isNotEmpty) ...[
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: _imagenes.length,
                          itemBuilder: (ctx, index) {
                            return Stack(
                              children: [
                                // Thumbnail
                                GestureDetector(
                                  onTap: () => _verImagenCompleta(_imagenes[index]),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      image: DecorationImage(
                                        image: FileImage(_imagenes[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                // Delete button
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _eliminarImagen(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                                // Index badge
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Botón agregar
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _imagenes.length >= _maxImagenes ? null : _mostrarOpcionesImagen,
                          icon: const Icon(Icons.add_a_photo),
                          label: Text(_imagenes.isEmpty
                              ? 'Agregar Fotos del Incidente'
                              : 'Agregar Más Fotos'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: BorderSide(color: Colors.indigo.withOpacity(0.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- EVIDENCIA DE AUDIO ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.mic, color: Colors.red, size: 22),
                          SizedBox(width: 8),
                          Text('Descripción por Voz (Audio)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_audioPath == null && !_isRecording)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _startRecording,
                            icon: const Icon(Icons.mic),
                            label: const Text('Grabar Explicación'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[50],
                              foregroundColor: Colors.red[700],
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        )
                      else if (_isRecording)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.circle, color: Colors.red, size: 12),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text('Grabando audio...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.stop, color: Colors.red),
                                onPressed: _stopRecording,
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green[100]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text('Audio Capturado', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: _eliminarAudio,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- GPS INFO ---
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.blue, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ubicación GPS', 
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(
                              widget.gpsReal != null
                                  ? '${widget.gpsReal!.latitude.toStringAsFixed(5)}, ${widget.gpsReal!.longitude.toStringAsFixed(5)}'
                                  : 'Capturando ubicación...',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        widget.gpsReal != null ? Icons.check_circle : Icons.sync,
                        color: widget.gpsReal != null ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                
                // --- BOTON DE SUBMIT ---
                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitIncidente,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('ENVIAR REPORTE (S.O.S)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        )));
  }
}
