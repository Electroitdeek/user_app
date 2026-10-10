import 'package:adhisaat_health_care/features/auth/login/bloc/auth_bloc.dart';
import 'package:adhisaat_health_care/data/repositories/auth_repository.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/core/services/network_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockNetworkService extends Mock implements NetworkService {}

void main() {
  late AuthBloc authBloc;
  late MockAuthRepository mockAuthRepository;
  late MockLocalStorageService mockLocalStorageService;
  late MockNetworkService mockNetworkService;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockLocalStorageService = MockLocalStorageService();
    mockNetworkService = MockNetworkService();
    
    authBloc = AuthBloc(
      repository: mockAuthRepository,
      storage: mockLocalStorageService,
      networkService: mockNetworkService,
    );
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc Tests', () {
    test('initial state should be AuthInitial', () {
      expect(authBloc.state, isA<AuthInitial>());
    });

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthOtpSent] when SendOtpEvent is successful',
      build: () {
        when(() => mockAuthRepository.sendOtp(
              mobile: any(named: 'mobile'),
              isResend: any(named: 'isResend'),
            )).thenAnswer((_) async => {
              'success': true,
              'status': true,
              'message': 'OTP sent successfully',
              'data': {'user': null}
            });
        return authBloc;
      },
      act: (bloc) => bloc.add(SendOtpEvent('9876543210')),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthOtpSent>().having((s) => s.mobile, 'mobile', '9876543210'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when SendOtpEvent fails due to blocked user',
      build: () {
        when(() => mockAuthRepository.sendOtp(
              mobile: any(named: 'mobile'),
              isResend: any(named: 'isResend'),
            )).thenAnswer((_) async => {
              'success': false,
              'status': false,
              'is_blocked': true,
              'message': 'Your account is blocked',
            });
        return authBloc;
      },
      act: (bloc) => bloc.add(SendOtpEvent('9876543210')),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>()
            .having((s) => s.message, 'message', 'Your account is blocked')
            .having((s) => s.isBlocked, 'isBlocked', true),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthGuest] when LoginAsGuest is added for Patient app',
      build: () {
        // AppConstants.isProviderApp = false; // Usually handled by flavoring/mocking constants
        when(() => mockLocalStorageService.clearAll()).thenAnswer((_) async => true);
        when(() => mockLocalStorageService.setOnboardingComplete(any())).thenAnswer((_) async => true);
        return authBloc;
      },
      act: (bloc) => bloc.add(LoginAsGuest()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthGuest>(),
      ],
    );
  });
}
