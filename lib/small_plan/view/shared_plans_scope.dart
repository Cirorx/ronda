import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/small_plan/cubit/shared_plans_cubit.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

/// Provides the [SharedPlansCubit] of ronda [rondaId] for [uid] to [child]:
/// the others' plans and the switch under the member's own. It is rebuilt
/// when the ronda changes.
class const SharedPlansScope({
  required final String rondaId,
  required final String uid,
  required final Widget child,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(rondaId),
    create: (context) => SharedPlansCubit(
      rondaId: rondaId,
      uid: uid,
      smallPlanRepository: context.read<SmallPlanRepository>(),
    )..subscribe(),
    child: child,
  );
}
