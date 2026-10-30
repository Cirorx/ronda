import 'package:bloc/bloc.dart';
import 'package:contact_repository/contact_repository.dart';
import 'package:equatable/equatable.dart';

part 'contact_state.dart';

/// Writing to Ronda and calling a helpline, from Ajustes: opens the mail
/// app or the dialer. When none opens, the state says which, so the screen
/// shows the address or the number to use by hand.
class ContactCubit extends Cubit<ContactState> {
  new({required this._contactRepository})
    : super(ContactState(email: _contactRepository.email));

  final ContactRepository _contactRepository;

  /// [Escribir un mail]: a new mail to Ronda with [subject], and [body]
  /// when given.
  Future<void> emailTapped({required String subject, String? body}) async {
    _clearFailure();
    try {
      await _contactRepository.writeEmail(subject: subject, body: body);
    } on ContactFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(
          ContactState(email: state.email, status: ContactStatus.emailFailed),
        );
      }
    }
  }

  /// A helpline's number: the dialer on it.
  Future<void> helplineTapped(Helpline helpline) async {
    _clearFailure();
    try {
      await _contactRepository.callHelpline(helpline);
    } on ContactFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(
          ContactState(
            email: state.email,
            status: ContactStatus.callFailed,
            helpline: helpline,
          ),
        );
      }
    }
  }

  /// Clears the last failure before a new try, so the same failure twice
  /// is shown twice.
  void _clearFailure() {
    if (state.status == ContactStatus.idle) return;
    emit(ContactState(email: state.email));
  }
}
