import 'dart:async';

import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/cuaderno/cubit/cuaderno_cubit.dart';
import 'package:ronda/cuaderno/cubit/line_voice_cubit.dart';
import 'package:ronda/cuaderno/view/cuaderno_view.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// El cuaderno del barrio: today's line, typed or said, the lines already
/// written, the one to bring to the meeting and the week's postcard
/// (`docs/PRODUCT.md` § El cuaderno del barrio).
class const CuadernoPage({super.key}) extends StatelessWidget {
  /// The route's segment under Mi ronda.
  static const segment = 'cuaderno';

  /// The route: a screen inside the Mi ronda tab.
  static const path = '/ronda/$segment';

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AppBloc>().state.user.id;
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final cubit = CuadernoCubit(
              uid: uid,
              cuadernoRepository: context.read<CuadernoRepository>(),
              rondaRepository: context.read<RondaRepository>(),
            );
            unawaited(cubit.started());
            return cubit;
          },
        ),
        BlocProvider(
          create: (context) => LineVoiceCubit(
            uid: uid,
            cuadernoRepository: context.read<CuadernoRepository>(),
          ),
        ),
      ],
      child: const CuadernoView(),
    );
  }
}
