import 'dart:async';
import 'package:adhisaat_health_care/features/user/emergency/bloc/emergency_map/emergency_map_bloc.dart';
import 'package:adhisaat_health_care/features/user/emergency/view/emergency_map_page.dart';
import 'package:adhisaat_health_care/features/user/service_booking/model/service_category_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:adhisaat_health_care/core/services/notification_service.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';
import 'package:adhisaat_health_care/features/user/address/data/user_address_repository.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';

class MockEmergencyMapBloc extends MockBloc<EmergencyMapEvent, EmergencyMapState> 
    implements EmergencyMapBloc {}
class MockNotificationService extends Mock implements NotificationService {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockUserAddressRepository extends Mock implements UserAddressRepository {}

void main() {
  late MockEmergencyMapBloc mockBloc;
  late MockNotificationService mockNotificationService;
  late MockLocalStorageService mockLocalStorageService;
  late MockUserAddressRepository mockUserAddressRepository;
  
  const mockCategory = ServiceCategoryModel(
    id: 1,
    categoryName: 'Ambulance',
    categorySlug: 'ambulance',
    isActive: true,
    displayOrder: 1,
    fullCategoryName: 'Emergency Ambulance',
  );

  setUp(() {
    mockBloc = MockEmergencyMapBloc();
    mockNotificationService = MockNotificationService();
    mockLocalStorageService = MockLocalStorageService();
    mockUserAddressRepository = MockUserAddressRepository();
    
    // Setup GetIt for testing
    locator.allowReassignment = true;
    if (locator.isRegistered<NotificationService>()) {
      locator.unregister<NotificationService>();
    }
    if (locator.isRegistered<LocalStorageService>()) {
      locator.unregister<LocalStorageService>();
    }
    if (locator.isRegistered<UserAddressRepository>()) {
      locator.unregister<UserAddressRepository>();
    }
    
    locator.registerSingleton<NotificationService>(mockNotificationService);
    locator.registerSingleton<LocalStorageService>(mockLocalStorageService);
    locator.registerSingleton<UserAddressRepository>(mockUserAddressRepository);
    
    // Default mock behavior
    when(() => mockNotificationService.registerBlocCallback(any())).thenReturn(null);
    when(() => mockNotificationService.unregisterBlocCallback(any())).thenReturn(null);
    when(() => mockLocalStorageService.getSelectedAddress()).thenAnswer((_) async => null);
  });

  tearDown(() {
    mockBloc.close();
  });

  testWidgets('EmergencyMapPage shows searching status and providers count', (tester) async {
    final controller = StreamController<EmergencyMapState>();
    
    // Set large screen size to avoid overflows
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    
    // 1. Setup the stream of states
    whenListen(
      mockBloc,
      controller.stream,
      initialState: EmergencyMapInitial(),
    );

    // 2. Build the widget
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(500, 1000),
        minTextAdapt: true,
        builder: (context, child) => ProviderScope(
          child: MaterialApp(
            home: BlocProvider<EmergencyMapBloc>.value(
              value: mockBloc,
              child: const EmergencyMapPage(category: mockCategory),
            ),
          ),
        ),
      ),
    );

    // 3. Move to Searching
    controller.add(EmergencyMapSearching(5.0));
    await tester.pump();
    expect(find.textContaining('Searching'), findsWidgets);

    // 4. Move to Providers Found
    controller.add(EmergencyMapProvidersFound(
      [{'provider_id': 1, 'provider_name': 'Dr. Hans'}],
      5.0,
      28.6139,
      77.2090,
      123,
      waitingWindowSeconds: 300,
    ));
    await tester.pump(); 
    expect(find.textContaining('1 Provider Notified'), findsOneWidget);
    
    await controller.close();
  });
}
