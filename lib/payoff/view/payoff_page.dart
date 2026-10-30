import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/login/login.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/payoff/payoff.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Esto es lo que hay para vos": after the read-back and before sign-in,
/// what the answers held on this phone find near the person.
class const PayoffPage({super.key}) extends StatelessWidget {
  static const path = '/lo-que-hay';

  /// Sign-in after the payoff, "Guardá tu lugar"; its back button returns
  /// here.
  static const signInPath = '$path/${LoginPage.segment}';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = PayoffCubit(
          profileRepository: context.read<ProfileRepository>(),
          rondaRepository: context.read<RondaRepository>(),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const PayoffView(),
    );
  }
}

/// The demand near the person, or that they are among the first, and
/// "Guardame el lugar". Never names, places or seats.
///
/// Back returns to the read-back, where the held answers open again.
class const PayoffView({super.key}) extends StatelessWidget {
  /// Maestro's handle on "Guardame el lugar".
  static const continueIdentifier = 'payoff.continue';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final state = context.watch<PayoffCubit>().state;

    void backToReadBack() => context.go(OnboardingPage.path);

    return BlocListener<PayoffCubit, PayoffState>(
      listenWhen: (_, current) => current.status == PayoffStatus.noAnswers,
      listener: (context, _) => backToReadBack(),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) backToReadBack();
        },
        child: Scaffold(
          appBar: AppBar(leading: BackButton(onPressed: backToReadBack)),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: spacing.lg,
                      vertical: spacing.sm,
                    ),
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.payoffTitle,
                          style: textTheme.headlineMedium,
                        ),
                      ),
                      SizedBox(height: spacing.lg),
                      ..._body(context, state),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    spacing.lg,
                    spacing.sm,
                    spacing.lg,
                    spacing.md,
                  ),
                  child: MergeSemantics(
                    child: Semantics(
                      identifier: continueIdentifier,
                      child: FilledButton(
                        onPressed: () => context.go(PayoffPage.signInPath),
                        child: Text(l10n.payoffContinue),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, PayoffState state) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    return switch (state) {
      PayoffState(status: PayoffStatus.loading || PayoffStatus.noAnswers) => [
        const Center(child: CircularProgressIndicator()),
      ],
      PayoffState(status: PayoffStatus.unavailable) => [
        NoteBanner(
          variant: NoteBannerVariant.offline,
          message: l10n.payoffUnavailable,
        ),
      ],
      PayoffState(:final demand) when demand.isEmpty => [
        Text(l10n.payoffFirstOnes, style: textTheme.bodyLarge),
      ],
      PayoffState(:final demand) => [
        for (final line in demand)
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: spacing.sm),
            child: NoteBanner(
              icon: Icons.groups_outlined,
              message: l10n.payoffDemandLine(line),
            ),
          ),
        SizedBox(height: spacing.xs),
        Text(l10n.payoffNext, style: textTheme.bodyLarge),
      ],
    };
  }
}

extension on AppLocalizations {
  /// "Hay 4 anotados para mate los sábados de tarde cerca tuyo."
  String payoffDemandLine(PayoffDemand line) {
    final pretext = payoffPretext(line.pretext.id);
    return switch (line.slot) {
      final slot? => payoffDemandAtSlot(
        line.count,
        pretext,
        payoffSlot(slot.day.id, slot.band.id),
      ),
      null => payoffDemand(line.count, pretext),
    };
  }
}
