import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';

/// The owner's approval screen, opened by its URL on web. Anyone signed in
/// may load it; only the admin claim gets a proposal back.
class const AdminPage({super.key}) extends StatelessWidget {
  static const path = '/admin';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ProposalsCubit(rondaRepository: context.read<RondaRepository>())
            ..subscribe(),
      child: const AdminView(),
    );
  }
}
