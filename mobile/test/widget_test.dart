import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config/env_config.dart';
import 'package:mobile/features/auth/models/user_model.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/auth/repositories/auth_repository.dart';
import 'package:mobile/features/auth/screens/login_screen.dart';
import 'package:mobile/features/camera/models/camera_model.dart';
import 'package:mobile/features/investigation/models/investigation_model.dart';

class MockAuthRepository extends AuthRepository {
  @override
  Future<UserModel?> restoreSession() async => null;
}

void main() {
  group('Police CCTV Mapping Unit & Widget Tests', () {
    testWidgets('LoginScreen renders police branding and inputs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(MockAuthRepository()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify header branding
      expect(find.text('POLICE SURVEILLANCE'), findsOneWidget);
      expect(find.text('CCTV Camera Mapping & Investigation System'), findsOneWidget);
      expect(find.text('Officer Sign In'), findsOneWidget);

      // Verify form elements
      expect(find.text('Username or Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Authenticate Session'), findsOneWidget);

      // Verify quick seed chips
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Officer'), findsOneWidget);
      expect(find.text('Surveyor'), findsOneWidget);
    });

    test('UserModel JSON serialization & role checks', () {
      final user = UserModel(
        id: 1,
        username: 'admin',
        email: 'admin@police.gov',
        fullName: 'System Administrator',
        role: 'ROLE_ADMIN',
        policeStationName: 'Nagpur Central',
      );

      expect(user.isAdmin, isTrue);
      expect(user.isOfficer, isFalse);
      expect(user.isSurveyor, isFalse);
      expect(user.roleDisplay, 'System Administrator');

      final json = user.toJson();
      final parsed = UserModel.fromJson(json);
      expect(parsed.username, 'admin');
      expect(parsed.role, 'ROLE_ADMIN');
    });

    test('CameraModel JSON serialization & defaults', () {
      final camera = CameraModel(
        id: 42,
        cameraCode: 'CAM-NAG-042',
        cameraName: 'Zero Mile Junction East',
        cameraType: 'PTZ',
        latitude: 21.1498,
        longitude: 79.0806,
        cameraStatus: 'ACTIVE',
        verificationStatus: 'APPROVED',
      );

      expect(camera.isApproved, isTrue);
      expect(camera.isActive, isTrue);
      expect(camera.directionAngle, 0.0);
      expect(camera.fovAngle, 60.0);

      final createJson = camera.toCreateJson();
      expect(createJson['cameraCode'], 'CAM-NAG-042');
      expect(createJson['latitude'], 21.1498);
    });

    test('InvestigationCaseModel JSON mapping', () {
      final json = {
        'id': 101,
        'caseNumber': 'CASE-2026-001',
        'title': 'Theft at Metro Station',
        'crimeType': 'THEFT',
        'crimeLocationName': 'Sitabuldi Interchange',
        'latitude': 21.1458,
        'longitude': 79.0882,
        'status': 'OPEN',
        'attachedCameras': [
          {
            'id': 1,
            'cameraCode': 'CAM-NAG-001',
            'cameraName': 'Metro Gate 1',
            'cameraType': 'BULLET',
            'latitude': 21.1459,
            'longitude': 79.0883,
          }
        ],
      };

      final caseModel = InvestigationCaseModel.fromJson(json);
      expect(caseModel.id, 101);
      expect(caseModel.caseNumber, 'CASE-2026-001');
      expect(caseModel.isOpen, isTrue);
      expect(caseModel.attachedCameras.length, 1);
      expect(caseModel.attachedCameras.first.cameraCode, 'CAM-NAG-001');
    });

    test('EnvConfig URL resolution', () {
      final config = EnvConfig();
      expect(config.resolveMediaUrl('https://supabase.co/img.jpg'), 'https://supabase.co/img.jpg');

      final relative = config.resolveMediaUrl('/api/v1/media/test.jpg');
      expect(relative, startsWith('http'));
      expect(relative, endsWith('/api/v1/media/test.jpg'));
    });
  });
}
