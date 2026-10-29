import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flyer_repository/flyer_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/mate_flyer/cubit/mate_flyer_cubit.dart';
import 'package:ronda/mate_flyer/view/mate_flyer_view.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Un mate de más": the host turns a photo of the group's things into the
/// flyer for ronda [rondaId]'s newcomer seat (`docs/PRODUCT.md` § Flyers).
class const MateFlyerPage({
  /// The ronda whose flyer this is.
  required final String rondaId,
  super.key,
}) extends StatelessWidget {
  /// The route, with the ronda's id in it.
  static const path = '/volante/:rondaId';

  /// Where ronda [rondaId]'s flyer screen is.
  static String location(String rondaId) =>
      '/volante/${Uri.encodeComponent(rondaId)}';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = MateFlyerCubit(
          uid: context.read<AppBloc>().state.user.id,
          rondaId: rondaId,
          flyerRepository: context.read<FlyerRepository>(),
        );
        unawaited(cubit.started());
        return cubit;
      },
      child: const MateFlyerView(),
    );
  }
}
