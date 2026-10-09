import 'package:url_launcher/url_launcher.dart';

import '../models/coordenada.dart';
import '../models/rota_ativa.dart';

class NavegacaoService {
  Uri googleMapsAte(Coordenada destino) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${destino.latitude},${destino.longitude}',
      'travelmode': 'driving',
      'dir_action': 'navigate',
    });
  }

  Uri wazeAte(Coordenada destino) {
    return Uri.https('waze.com', '/ul', {
      'll': '${destino.latitude},${destino.longitude}',
      'navigate': 'yes',
      'utm_source': 'AplicativoDeRotas',
    });
  }

  Uri googleMapsRotaCompleta(RotaAtiva rota) {
    final intermediarios = rota.pontosIntermediariosGoogle;
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': '${rota.origem.latitude},${rota.origem.longitude}',
      'destination':
          '${rota.destinoFinalGoogle.latitude},${rota.destinoFinalGoogle.longitude}',
      if (intermediarios.isNotEmpty)
        'waypoints': intermediarios
            .map((ponto) => '${ponto.latitude},${ponto.longitude}')
            .join('|'),
      'travelmode': 'driving',
      'dir_action': 'navigate',
    });
  }

  Future<void> abrir(Uri uri) async {
    final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abriu) {
      throw Exception('Nenhum aplicativo conseguiu abrir a navegação.');
    }
  }
}
