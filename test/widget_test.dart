// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:music_visualizer/main.dart';
// ignore: unnecessary_import
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// 1. Mockito를 사용하여 PermissionHandlerPlatform의 Mock 클래스를 생성합니다.
//    - Mock을 상속하고, MockPlatformInterfaceMixin을 with 합니다.
class MockPermissionHandler extends Mock
    with MockPlatformInterfaceMixin
    implements PermissionHandlerPlatform {
  // 2. requestPermissions 메소드를 override하여, 테스트 시 특정 결과를 반환하도록 설정합니다.
  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(List<Permission> permissions) {
    // `noSuchMethod`를 사용하여 이 메소드 호출에 대한 응답을 설정합니다.
    // when(...).thenAnswer(...) 구문을 사용하여 테스트 케이스별로 다른 값을 반환하게 됩니다.
    return super.noSuchMethod(
      Invocation.method(#requestPermissions, [permissions]),
      returnValue: Future.value({Permission.microphone: PermissionStatus.granted}),
    ) as Future<Map<Permission, PermissionStatus>>;
  }

  // 아래는 인터페이스에 정의되어 있지만 이번 테스트에서는 직접적으로 호출되지 않는 메소드들입니다.
  // non-nullable을 반환해야 하므로, 테스트에 영향을 주지 않는 기본값을 설정합니다.
  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      PermissionStatus.granted;

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) async => ServiceStatus.enabled;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> shouldShowRequestPermissionRationale(Permission permission) async => false;
}

void main() {
  // 테스트에서 사용할 Mock 인스턴스를 생성합니다.
  final mockPermissionHandler = MockPermissionHandler();

  // 3. 각 테스트가 실행되기 전에 PlatformInterface가 우리의 Mock 인스턴스를 사용하도록 설정합니다.
  setUp(() {
    PermissionHandlerPlatform.instance = mockPermissionHandler;
  });

  testWidgets('마이크 권한이 허용되면 "granted" 메시지를 표시한다', (WidgetTester tester) async {
    // 준비: Mock 객체가 'granted' 상태를 반환하도록 설정합니다.
    when(mockPermissionHandler.requestPermissions([Permission.microphone]))
        .thenAnswer((_) async => {Permission.microphone: PermissionStatus.granted});

    // 실행
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 검증
    expect(find.text('Permission granted! Starting audio stream...'), findsOneWidget);
    expect(
        find.text('Permission denied. Please grant microphone access in settings.'), findsNothing);
  });

  testWidgets('마이크 권한이 거부되면 "denied" 메시지를 표시한다', (WidgetTester tester) async {
    // 준비: Mock 객체가 'denied' 상태를 반환하도록 설정합니다.
    when(mockPermissionHandler.requestPermissions([Permission.microphone]))
        .thenAnswer((_) async => {Permission.microphone: PermissionStatus.denied});

    // 실행
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 검증
    expect(find.text('Permission denied. Please grant microphone access in settings.'),
        findsOneWidget);
    expect(find.text('Permission granted! Starting audio stream...'), findsNothing);
  });
}
