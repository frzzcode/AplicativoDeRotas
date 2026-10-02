import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/services/rota_service.dart';

class RotaMapa extends StatelessWidget {
  final ResultadoRota resultado;

  const RotaMapa({super.key, required this.resultado});

  LatLng _ponto(double latitude, double longitude) =>
      LatLng(latitude, longitude);

  @override
  Widget build(BuildContext context) {
    final linha = [
      for (final ponto in resultado.geometria)
        _ponto(ponto.latitude, ponto.longitude),
    ];
    final origem = _ponto(
      resultado.origem.latitude,
      resultado.origem.longitude,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 380,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: linha,
              padding: const EdgeInsets.all(36),
              maxZoom: 17,
            ),
            minZoom: 3,
            maxZoom: 19,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.tcc_rotas_tecnico',
              maxNativeZoom: 19,
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: linha,
                  strokeWidth: 6,
                  color: const Color(0xFF1565C0),
                  borderStrokeWidth: 2,
                  borderColor: Colors.white,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: origem,
                  width: 44,
                  height: 44,
                  child: const _Marcador(
                    texto: 'I',
                    cor: Color(0xFF2E7D32),
                    icone: Icons.home,
                  ),
                ),
                for (var i = 0; i < resultado.coordenadasParadas.length; i++)
                  Marker(
                    point: _ponto(
                      resultado.coordenadasParadas[i].latitude,
                      resultado.coordenadasParadas[i].longitude,
                    ),
                    width: 44,
                    height: 44,
                    child: _Marcador(
                      texto: '${i + 1}',
                      cor: const Color(0xFF1565C0),
                    ),
                  ),
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Marcador extends StatelessWidget {
  final String texto;
  final Color cor;
  final IconData? icone;

  const _Marcador({required this.texto, required this.cor, this.icone});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: icone == null
            ? Text(
                texto,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : Icon(icone, color: Colors.white, size: 21),
      ),
    );
  }
}
