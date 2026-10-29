import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';

/// The owner's approval screen, opened by its URL on web, with the weekly
/// RSVP's "Mandarlo ahora". Anyone signed in may load it; only the admin
/// claim gets a proposal back or sends anything.
class const AdminPage({super.key}) extends StatelessWidget {
  static const path = '/admin';

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              ProposalsCubit(rondaRepository: context.read<RondaRepository>())
                ..subscribe(),
        ),
        BlocProvider(
          create: (context) =>
              RsvpPushCubit(rondaRepository: context.read<RondaRepository>()),
        ),
      ],
      child: const AdminView(),
    );
  }
}
