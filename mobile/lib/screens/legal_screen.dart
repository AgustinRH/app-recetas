import 'package:flutter/material.dart';

import '../theme.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.kind});

  final LegalKind kind;

  @override
  Widget build(BuildContext context) {
    final privacy = kind == LegalKind.privacy;
    return Scaffold(
      appBar: AppBar(title: Text(privacy ? 'Privacidad' : 'Condiciones')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            privacy ? 'Cómo tratamos tus datos' : 'Cómo se usa DishToday',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '1 de octubre de 2026',
            style: TextStyle(color: ink.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 16),
          ..._blocks(privacy),
        ],
      ),
    );
  }

  List<Widget> _blocks(bool privacy) {
    final sections = privacy ? _privacy : _terms;
    return [
      for (final section in sections) ...[
        Text(section.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 6),
        Text(section.$2, style: const TextStyle(height: 1.4, fontSize: 15)),
        const SizedBox(height: 18),
      ],
    ];
  }
}

enum LegalKind { privacy, terms }

const _contact = 'agusrubher@gmail.com';

const _privacy = <(String, String)>[
  (
    'Quién es el responsable',
    'DishToday la lleva Agustín Rubí Hernández. Para cualquier cosa sobre tus datos escribe a $_contact.',
  ),
  (
    'Qué datos hay',
    'La cuenta: correo, nombre y, si entras con Google, la foto de ese perfil. '
        'Lo que tú guardas: despensa, lista de la compra, plan de la semana, recetas, fotos, comentarios, me gusta y recetas guardadas. '
        'Si los indicas, también la dieta y las alergias. Las denuncias que envíes, con el motivo y el texto.',
  ),
  (
    'Para qué',
    'Para crear tu cuenta, decirte qué puedes cocinar con lo que tienes, guardar tu plan y enseñar lo que publicas. '
        'La dieta y las alergias solo sirven para personalizar tu experiencia y no se muestran a otras personas. '
        'Las cifras de nutrición son una estimación de la receta, no un consejo médico.',
  ),
  (
    'Quién más los ve',
    'El inicio de sesión lo hace Firebase, de Google. La app y las fotos están en un servidor de Hetzner, en la Unión Europea. '
        'No vendemos tus datos. Tu nombre aparece en las recetas y comentarios que publicas. El correo no se muestra al resto.',
  ),
  (
    'Cuánto tiempo',
    'Mientras la cuenta exista. Al borrarla desde Perfil se quitan el perfil, la despensa, el plan, la compra y lo que hayas publicado.',
  ),
  (
    'Tus derechos',
    'Puedes ver y corregir tu nombre, tu dieta y tus alergias dentro de la app. '
        'En Perfil está «Borrar mi cuenta»: quita el perfil, la despensa, el plan, la compra, lo que hayas publicado y el acceso. '
        'Para pedir una copia de tus datos, escribe a $_contact. '
        'También puedes reclamar ante la Agencia Española de Protección de Datos.',
  ),
];

const _terms = <(String, String)>[
  (
    'El servicio',
    'DishToday te ayuda a ver qué cocinar con lo que tienes en casa, a guardar un plan de la semana y a publicar recetas. '
        'Se ofrece tal como está. Puede cambiar o dejar de estar disponible.',
  ),
  (
    'Tu cuenta',
    'Eres responsable de lo que haces con tu acceso. No uses la app si tienes menos de 16 años.',
  ),
  (
    'Lo que publicas',
    'Las recetas y las fotos que subes siguen siendo tuyas. Al publicarlas nos dejas mostrarlas dentro de DishToday. '
        'No subas contenido ilegal, datos de otras personas o fotos y textos que no puedas usar. '
        'Podemos quitar una publicación o suspender una cuenta si incumple esto o si alguien la denuncia.',
  ),
  (
    'El catálogo',
    'Las recetas de partida son textos propios. Cuando una foto viene de Wikimedia Commons, la ficha indica el autor y la licencia.',
  ),
  (
    'Nutrición',
    'Calorías y macros son orientativos. No sustituyen el criterio de un profesional sanitario.',
  ),
  (
    'Contacto',
    'Dudas sobre estas condiciones: $_contact.',
  ),
];
