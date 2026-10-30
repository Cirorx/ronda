import 'package:bloc_test/bloc_test.dart';
import 'package:contact_repository/contact_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/settings/settings.dart';

class _MockContactRepository extends Mock implements ContactRepository;

const _email = 'hola@example.com';

void main() {
  group(ContactCubit, () {
    late ContactRepository contactRepository;

    setUp(() {
      contactRepository = _MockContactRepository();
      when(() => contactRepository.email).thenReturn(_email);
      when(
        () => contactRepository.writeEmail(
          subject: any(named: 'subject'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async {});
      when(() => contactRepository.callHelpline(Helpline.emergencies))
          .thenAnswer((_) async {});
    });

    ContactCubit build() => ContactCubit(contactRepository: contactRepository);

    test('starts with the contact address and nothing failed', () {
      expect(build().state, equals(const ContactState(email: _email)));
    });

    group('emailTapped', () {
      blocTest<ContactCubit, ContactState>(
        'opens a mail with the subject and body',
        build: build,
        act: (cubit) => cubit.emailTapped(subject: 'Asunto', body: 'Cuerpo'),
        expect: () => const <ContactState>[],
        verify: (_) => verify(
          () => contactRepository.writeEmail(subject: 'Asunto', body: 'Cuerpo'),
        ).called(1),
      );

      blocTest<ContactCubit, ContactState>(
        'says so when no mail app opens, and clears it on the next try',
        setUp: () => when(
          () => contactRepository.writeEmail(subject: any(named: 'subject')),
        ).thenThrow(const ContactFailure()),
        build: build,
        act: (cubit) async {
          await cubit.emailTapped(subject: 'Asunto');
          await cubit.emailTapped(subject: 'Asunto');
        },
        expect: () => const [
          ContactState(email: _email, status: ContactStatus.emailFailed),
          ContactState(email: _email),
          ContactState(email: _email, status: ContactStatus.emailFailed),
        ],
        errors: () => [isA<ContactFailure>(), isA<ContactFailure>()],
      );

      blocTest<ContactCubit, ContactState>(
        'emits no failure once closed',
        setUp: () =>
            when(
              () =>
                  contactRepository.writeEmail(subject: any(named: 'subject')),
            ).thenAnswer(
              (_) => Future.delayed(
                Duration.zero,
                () => throw const ContactFailure(),
              ),
            ),
        build: build,
        act: (cubit) async {
          final writing = cubit.emailTapped(subject: 'Asunto');
          await cubit.close();
          await writing;
        },
        expect: () => const <ContactState>[],
      );
    });

    group('helplineTapped', () {
      blocTest<ContactCubit, ContactState>(
        'opens the dialer on the line',
        build: build,
        act: (cubit) => cubit.helplineTapped(Helpline.emergencies),
        expect: () => const <ContactState>[],
        verify: (_) =>
            verify(() => contactRepository.callHelpline(Helpline.emergencies))
                .called(1),
      );

      blocTest<ContactCubit, ContactState>(
        'says which line did not open',
        setUp: () => when(
          () => contactRepository.callHelpline(Helpline.suicidePrevention),
        ).thenThrow(const ContactFailure()),
        build: build,
        act: (cubit) => cubit.helplineTapped(Helpline.suicidePrevention),
        expect: () => const [
          ContactState(
            email: _email,
            status: ContactStatus.callFailed,
            helpline: Helpline.suicidePrevention,
          ),
        ],
        errors: () => [isA<ContactFailure>()],
      );

      blocTest<ContactCubit, ContactState>(
        'emits no failure once closed',
        setUp: () =>
            when(() => contactRepository.callHelpline(Helpline.emergencies))
                .thenAnswer(
                  (_) => Future.delayed(
                    Duration.zero,
                    () => throw const ContactFailure(),
                  ),
                ),
        build: build,
        act: (cubit) async {
          final calling = cubit.helplineTapped(Helpline.emergencies);
          await cubit.close();
          await calling;
        },
        expect: () => const <ContactState>[],
      );
    });
  });
}
