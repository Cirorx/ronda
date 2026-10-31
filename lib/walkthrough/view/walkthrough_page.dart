import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/walkthrough/walkthrough.dart';
import 'package:ronda/welcome/welcome.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template walkthrough_page}
/// "¿Cómo funciona?": three cards a signed-out person sees before the
/// welcome doors the first time they open the app, and again from the
/// welcome screen's link.
///
/// Leaving it for the doors adds [AppWalkthroughSeen], so it isn't
/// shown on its own again. (Marking it on open would change the router's
/// state while the redirect to it is still settling, and send people on to
/// the doors before they saw it.)
///
/// The cards move with a swipe, settling on the app's spring
/// ([WalkthroughPhysics]), with "Seguir" and with the arrow keys; "Saltear"
/// and the last card's "Empezar" lead to the welcome doors. With reduced
/// motion the buttons and keys change card at once. Wider than a phone it
/// keeps to a readable column.
/// {@endtemplate}
class WalkthroughPage extends StatefulWidget {
  /// {@macro walkthrough_page}
  const new({super.key});

  /// Where the router sends a first-time visitor.
  static const path = '/como-funciona';

  /// Maestro's handle on "Saltear".
  static const skipIdentifier = 'walkthrough.skip';

  /// Maestro's handle on "Seguir" and "Empezar".
  static const nextIdentifier = 'walkthrough.next';

  /// How many cards there are.
  static const cardCount = 3;

  @override
  State<WalkthroughPage> createState() => _WalkthroughPageState();
}

class _WalkthroughPageState extends State<WalkthroughPage> {
  final _controller = PageController();
  var _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _onLast => _index == WalkthroughPage.cardCount - 1;

  /// Opens card [index]. The target, not the card on screen, is the next
  /// move's start, so quick key presses never queue up behind a slide.
  void _open(int index) {
    if (index < 0 || index >= WalkthroughPage.cardCount || index == _index) {
      return;
    }
    setState(() => _index = index);
    if (RondaMotion.of(context).reduced) {
      _controller.jumpToPage(index);
    } else {
      _controller.animateToPage(
        index,
        duration: AppMotion.standardDuration,
        curve: AppMotion.standardCurve,
      );
    }
  }

  /// On to the welcome doors, remembering it was seen: back to them when
  /// they are underneath (the welcome screen's link), or in their place.
  void _finish() {
    context.read<AppBloc>().add(const AppWalkthroughSeen());
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(WelcomePage.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final motion = RondaMotion.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    void forward() => _open(_index + 1);
    void backward() => _open(_index - 1);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): rtl
            ? backward
            : forward,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): rtl
            ? forward
            : backward,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: ReadableColumn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: spacing.xs,
                        top: spacing.xs,
                      ),
                      child: MergeSemantics(
                        child: Semantics(
                          identifier: WalkthroughPage.skipIdentifier,
                          child: TextButton(
                            onPressed: _finish,
                            child: Text(l10n.walkthroughSkip),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      physics: WalkthroughPhysics(reduced: motion.reduced),
                      onPageChanged: (index) => setState(() => _index = index),
                      children: [
                        WalkthroughCard(
                          art: WalkthroughArt.objects(),
                          title: l10n.walkthroughGroupTitle,
                          body: l10n.walkthroughGroupBody,
                        ),
                        WalkthroughCard(
                          art: const WeekCardPreview(),
                          decorative: false,
                          title: l10n.walkthroughWeekTitle,
                          body: l10n.walkthroughWeekBody,
                        ),
                        WalkthroughCard(
                          art: WalkthroughArt.logistics(),
                          title: l10n.walkthroughProgramTitle,
                          body: l10n.walkthroughProgramBody,
                        ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: spacing.md,
                      children: [
                        WalkthroughDots(
                          index: _index,
                          count: WalkthroughPage.cardCount,
                        ),
                        MergeSemantics(
                          child: Semantics(
                            identifier: WalkthroughPage.nextIdentifier,
                            child: FilledButton(
                              onPressed: _onLast ? _finish : forward,
                              child: Text(
                                _onLast
                                    ? l10n.walkthroughStart
                                    : l10n.walkthroughNext,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
