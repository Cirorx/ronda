import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/phone_login/phone_login.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Two steps: "¿Cuál es tu celular?" with `+598` filled in and
/// "Mandame el código", then "Escribí el código" with "Entrar", a resend
/// that counts down and "Cambiar el número". A failure says so in a banner
/// that is read out; a field that is not valid says why under it.
class const PhoneLoginView({super.key}) extends StatefulWidget {
  /// Maestro's handles.
  static const numberFieldIdentifier = 'phone_number';
  static const sendButtonIdentifier = 'phone_send';
  static const codeFieldIdentifier = 'phone_code';
  static const confirmButtonIdentifier = 'phone_confirm';
  static const resendButtonIdentifier = 'phone_resend';
  static const changeNumberIdentifier = 'phone_change_number';

  @override
  State<PhoneLoginView> createState() => _PhoneLoginViewState();
}

class _PhoneLoginViewState extends State<PhoneLoginView> {
  late final TextEditingController _number;
  final TextEditingController _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    _number = TextEditingController(
      text: context.read<PhoneLoginCubit>().state.number.value,
    );
  }

  @override
  void dispose() {
    _number.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final step = context.select<PhoneLoginCubit, PhoneLoginStep>(
      (cubit) => cubit.state.step,
    );

    return BlocListener<PhoneLoginCubit, PhoneLoginState>(
      // A new code starts with an empty field.
      listenWhen: (previous, current) =>
          previous.verification != current.verification,
      listener: (_, _) => _code.clear(),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.phoneLoginBarTitle)),
        body: SafeArea(
          // Each step scrolls on its own, so the switcher has the whole
          // height to slide them in.
          child: StepSwitcher<PhoneLoginStep>(
            step: step,
            forward: (_, to) => to == PhoneLoginStep.code,
            child: ReadableColumn(
              child: ListView(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: spacing.lg,
                  vertical: spacing.md,
                ),
                children: [
                  switch (step) {
                    PhoneLoginStep.number => _NumberStep(controller: _number),
                    PhoneLoginStep.code => _CodeStep(controller: _code),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class const _NumberStep({required final TextEditingController controller})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final state = context.watch<PhoneLoginCubit>().state;
    final cubit = context.read<PhoneLoginCubit>();
    final sending = state.status == PhoneLoginStatus.sending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.phoneLoginNumberTitle,
            style: textTheme.headlineMedium,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(l10n.phoneLoginNumberBody, style: textTheme.bodyLarge),
        SizedBox(height: spacing.lg),
        Semantics(
          identifier: PhoneLoginView.numberFieldIdentifier,
          child: TextField(
            controller: controller,
            enabled: !state.busy,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.send,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-().]')),
            ],
            decoration: InputDecoration(
              labelText: l10n.phoneLoginNumberLabel,
              helperText: l10n.phoneLoginNumberHint,
              helperMaxLines: 2,
              errorMaxLines: 3,
              errorText: state.showInputError
                  ? switch (state.number.error) {
                      PhoneNumberError.empty => l10n.phoneLoginNumberEmpty,
                      PhoneNumberError.notMobile =>
                        l10n.phoneLoginNumberNotMobile,
                      PhoneNumberError.invalid => l10n.phoneLoginNumberInvalid,
                      null => null,
                    }
                  : null,
            ),
            onChanged: cubit.numberChanged,
            onSubmitted: (_) => unawaited(cubit.sendCode()),
          ),
        ),
        SizedBox(height: spacing.lg),
        if (state.error case final error?) ...[
          _ErrorBanner(error: error),
          SizedBox(height: spacing.md),
        ],
        MergeSemantics(
          child: Semantics(
            identifier: PhoneLoginView.sendButtonIdentifier,
            child: IgnorePointer(
              ignoring: state.busy,
              child: FilledButton(
                onPressed: () => unawaited(cubit.sendCode()),
                child: BusyLabel(
                  sending ? l10n.phoneLoginSending : l10n.phoneLoginSendButton,
                  busy: sending,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class const _CodeStep({required final TextEditingController controller})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final state = context.watch<PhoneLoginCubit>().state;
    final cubit = context.read<PhoneLoginCubit>();
    final confirming =
        state.status == PhoneLoginStatus.confirming ||
        state.status == PhoneLoginStatus.success;
    final number = state.verification?.phoneNumber.display ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.phoneLoginCodeTitle,
            style: textTheme.headlineMedium,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(l10n.phoneLoginCodeBody(number), style: textTheme.bodyLarge),
        if (state.resent) ...[
          SizedBox(height: spacing.xs),
          StatusLine(l10n.phoneLoginResent),
        ],
        SizedBox(height: spacing.lg),
        Semantics(
          identifier: PhoneLoginView.codeFieldIdentifier,
          child: TextField(
            controller: controller,
            enabled: !state.busy,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(SmsCode.length),
            ],
            decoration: InputDecoration(
              labelText: l10n.phoneLoginCodeLabel,
              errorText: state.showInputError && state.code.isNotValid
                  ? l10n.phoneLoginCodeInvalid
                  : null,
            ),
            onChanged: cubit.codeChanged,
            onSubmitted: (_) => unawaited(cubit.confirmCode()),
          ),
        ),
        SizedBox(height: spacing.lg),
        if (state.error case final error?) ...[
          _ErrorBanner(error: error),
          SizedBox(height: spacing.md),
        ],
        MergeSemantics(
          child: Semantics(
            identifier: PhoneLoginView.confirmButtonIdentifier,
            child: IgnorePointer(
              ignoring: state.busy,
              child: FilledButton(
                onPressed: () => unawaited(cubit.confirmCode()),
                child: BusyLabel(
                  confirming
                      ? l10n.phoneLoginConfirming
                      : l10n.phoneLoginConfirmButton,
                  busy: confirming,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: spacing.xs),
        if (state.noMoreResends)
          Padding(
            padding: EdgeInsetsDirectional.symmetric(vertical: spacing.sm),
            child: Text(
              l10n.phoneLoginNoMoreResends,
              style: textTheme.bodyMedium,
            ),
          )
        else
          Semantics(
            identifier: PhoneLoginView.resendButtonIdentifier,
            child: TextButton(
              onPressed: state.busy || state.secondsToResend > 0
                  ? null
                  : () => unawaited(cubit.resendCode()),
              child: Text(
                state.secondsToResend > 0
                    ? l10n.phoneLoginResendIn(state.secondsToResend)
                    : state.status == PhoneLoginStatus.sending
                    ? l10n.phoneLoginSending
                    : l10n.phoneLoginResendButton,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        Semantics(
          identifier: PhoneLoginView.changeNumberIdentifier,
          child: TextButton(
            onPressed: state.busy ? null : cubit.changeNumber,
            child: Text(
              l10n.phoneLoginChangeNumber,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

class const _ErrorBanner({required final PhoneLoginError error})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return NoteBanner(
      variant: error == PhoneLoginError.network
          ? NoteBannerVariant.offline
          : NoteBannerVariant.warning,
      message: switch (error) {
        PhoneLoginError.invalidNumber => l10n.phoneLoginNumberInvalid,
        PhoneLoginError.tooManyRequests => l10n.phoneLoginTooManyRequests,
        PhoneLoginError.unavailable => l10n.phoneLoginUnavailable,
        PhoneLoginError.wrongCode => l10n.phoneLoginWrongCode,
        PhoneLoginError.expiredCode => l10n.phoneLoginExpiredCode,
        PhoneLoginError.network => l10n.loginNetworkError,
        PhoneLoginError.other => l10n.loginError,
      },
    );
  }
}
