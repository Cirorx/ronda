import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';

/// The owner's approval screen, the Admin tab, with the weekly RSVP's
/// "Mandarlo ahora" and the ¿seguimos? counts. The app builds it only for
/// the account whose token carries the admin claim ([AdminGate]); the
/// server checks the claim again for every proposal, send and count.
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
        BlocProvider(
          create: (context) => SeguimosCountsCubit(
            rondaRepository: context.read<RondaRepository>(),
          )..subscribe(),
        ),
        pilotNumbersProvider(),
      ],
      child: const AdminView(),
    );
  }
}
