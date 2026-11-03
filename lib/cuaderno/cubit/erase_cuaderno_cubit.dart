import 'package:bloc/bloc.dart';
import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:error_reporter/error_reporter.dart';

/// Where deleting the cuaderno stands.
enum EraseCuadernoStatus {
  /// Nothing asked yet.
  idle,

  /// Deleting.
  erasing,

  /// Deleted: "Se borró tu cuaderno."
  erased,

  /// It couldn't be deleted.
  failed,
}

/// Ajustes → Tus datos → "Borrar mi cuaderno": one action that removes the
/// whole cuaderno from this phone. It has nothing to ask the server: the
/// cuaderno was never there.
class EraseCuadernoCubit extends Cubit<EraseCuadernoStatus>
    implements StepNamed {
  new({required this._uid, required this._cuadernoRepository})
    : super(EraseCuadernoStatus.idle);

  final String _uid;
  final CuadernoRepository _cuadernoRepository;

  /// The person confirmed.
  Future<void> erase() async {
    if (state == EraseCuadernoStatus.erasing) return;
    emit(EraseCuadernoStatus.erasing);
    try {
      await _cuadernoRepository.clear(_uid);
      emit(EraseCuadernoStatus.erased);
    } on Exception catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(EraseCuadernoStatus.failed);
    }
  }

  @override
  String get reportStep => 'EraseCuadernoCubit';
}
