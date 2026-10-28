
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'features/clinic/models/clinic.dart';


class SQLdata {
  String phpapi = kServerBaseUrl;
  String convertLocalPathToUrl(String localFilePath) {
    // Replace the WAMP folder with the server base URL (phpapi ends with '/')
    String url = localFilePath.replaceFirst("C:/wamp64/www/reed/", phpapi);

    return url;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final String url = "${phpapi}login.php";
    try {
      final res = await http.post(
        Uri.parse(url),
        body: {
          "email": email,
          "password": password,
        },
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        if (decoded is! Map<String, dynamic>) {
          return {
            "error": true,
            "id": null,
            "message": "Invalid response format from server"
          };
        }

        final Map<String, dynamic> data = decoded;

        return data;
      } else {
        return {
          "error": true,
          "id": null,
          "message": "Error: PHP API returned status code ${res.statusCode}"
        };
      }
    } on TimeoutException {
      return {
        "error": true,
        "id": null,
        "message": "Connection timeout. Please check server/network and try again."
      };
    } on SocketException {
      return {
        "error": true,
        "id": null,
        "message": "Unable to reach server. Verify WAMP server IP and firewall settings."
      };
    } catch (e) {
      return {
        "error": true,
        "id": null,
        "message": "Exception: $e"
      };
    }
  }

  Future<List> fetchSlots() async {
    List<dynamic> slots = [];
    try {
      final response = await http.get(Uri.parse("${phpapi}get_available_slots.php"));
      if (response.statusCode == 200) {
        List<dynamic> slotdata  = json.decode(response.body);
        slots = slotdata.where((slot) => slot['isAvailable'] == '1').toList();
        return slots;
      } else {
        return [];
      }}
    catch (e) {
      return [];
    }
  }

  Future<Map> bookSlot(dynamic slot, String reason, int id) async {
    String splitted = slot['slotDate'];
    String date = splitted.split(" ").first;

    final response = await http.post(
      Uri.parse("${phpapi}book_appointment.php"),
      body: {
        "date": date,
        "time": slot['slotDate'], // optional static/default time
        "reason": reason,
        "patientID": id.toString(),
        "slotID": slot['slotID'].toString(),
      },
    );
    if (response.statusCode == 200) {
      Map data = json.decode(response.body);

      return data;
    } else {
      return {};
    }

  }

 /* Future<List<Scan>> fetchScans(int patientId) async {
    final response = await http.post(
      Uri.parse("${phpapi}get_scans.php"),
      body: {'patientID': patientId.toString()},
    );
    final data = json.decode(response.body);
    if (!data['error']) {
      return (data['scans'] as List)
          .map((json) => Scan.fromJsonWithApi(json,phpapi))
          .toList();
    } else {
      throw Exception(data['message']);
    }
  }
*/

  Future<Map<String, dynamic>> fetchProfile(int patientID) async {
    final response = await http.post(
      Uri.parse("${phpapi}get_patient_profile.php"),
      body: {'patientID': patientID.toString()},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['error'] == false && data['profile'] != null) {
        // Extract profile data
        final profile = data['profile'];

        // Decode location JSON string
        Map<String, double> locationData = {'latitude': 0.0, 'longitude': 0.0};
        if (profile['location'] != null) {
          var locationJson = json.decode(profile['location']);
          // Explicitly cast the values to double
          locationData = {
            'latitude': double.tryParse(locationJson['latitude'].toString()) ?? 0.0,
            'longitude': double.tryParse(locationJson['longitude'].toString()) ?? 0.0,
          };
        }

        // Return the profile data in a map
        return {
          'address': profile['p_Address'] ?? '',
          'phone': profile['p_phoneNum'].toString(),
          'wilaya': profile['p_wilaya'] ?? '',
          'dob': profile['p_dob'] ?? '',
          'gender': profile['p_gender'] ?? '',
          'location': locationData,
        };
      }
      throw Exception("Failed to load profile");
    } else {
      throw Exception("Failed to load profile");
    }
  }

  Future<bool> saveProfile(int patientID, Map<String, dynamic> profileData) async {
    final locationData = json.encode({
      'latitude': profileData['latitude'],
      'longitude': profileData['longitude'],
    });

    final response = await http.post(
      Uri.parse("${phpapi}update_patient_profil.php"),
      body: {
        "patientID": patientID.toString(),
        "p_Address": profileData["p_Address"],
        "p_phoneNum": profileData["p_phoneNum"].toString(),
        "p_wilaya": profileData["p_wilaya"],
        "p_dob": profileData["p_dob"],
        "p_gender": profileData["p_gender"],
        "location": locationData, // Send the location as JSON string
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return !data['error'];
    }
    return false;
  }

 /* Future<List<ScanResult>> getPatientScans(String patientID) async {
    final url = Uri.parse("${phpapi}get_results.php"); // Your PHP script URL

    final response = await http.post(
      url,
      body: {'patientID': patientID},
    );

    if (response.statusCode == 200) {

      final List<dynamic> jsonData = jsonDecode(response.body);
      print("Parsed JSON data: $jsonData");
      return jsonData.map((item) => ScanResult.fromJson(item,phpapi)).toList();
    } else {
      // If the request failed, throw an error
      throw Exception('Failed to load scan results');
    }
  }*/

  Future<List<dynamic>> fetchAppointments(int patientId) async {
    final response = await http.get(Uri.parse("${phpapi}get_appointement.php?patientID=$patientId"));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['success']) {
        return data['appointments'];
      } else {
        throw Exception(data['message']);
      }
    } else {
      throw Exception("Failed to load appointments");
    }
  }

  Future<bool> uploadScan(File imageFile, int patientId) async {
    final now = DateTime.now();
    final uploadDate = DateFormat('yyyy-MM-dd').format(now);
    final uploadTime = DateFormat('HH:mm:ss').format(now);

    final uri = Uri.parse("${phpapi}upload_scan.php");
    final request = http.MultipartRequest('POST', uri);

    request.files.add(await http.MultipartFile.fromPath('scanImage', imageFile.path));
    request.fields['Patient_patientID'] = patientId.toString();
    request.fields['source'] = 'upload';
    request.fields['uploadDate'] = uploadDate;
    request.fields['uploadTime'] = uploadTime;

    try {
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> signup(Map<String, dynamic> data) async {
    // Backward-compatible wrapper: signup now supports clinic registration only.
    return clinicSignup(
      email: (data['email'] ?? '').toString(),
      password: (data['password'] ?? '').toString(),
      clinicName: (data['clinic_name'] ?? data['name'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      justifFile: data['justif_file'] is File ? data['justif_file'] as File : null,
    );
  }

  Future<Map<String, dynamic>> clinicSignup({
    required String email,
    required String password,
    required String clinicName,
    String address = '',
    String phone = '',
    File? justifFile,
  }) async {
    final uri = Uri.parse('${phpapi}signup.php');
    final request = http.MultipartRequest('POST', uri)
      ..fields['email'] = email
      ..fields['password'] = password
      ..fields['clinic_name'] = clinicName
      ..fields['address'] = address
      ..fields['phone'] = phone;

    if (justifFile != null) {
      request.files.add(await http.MultipartFile.fromPath('justif', justifFile.path));
    }

    try {
      final streamed = await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) {
        return {'error': true, 'message': 'Server error: ${response.statusCode}'};
      }
      return _decodeJsonMapResponse(response.body, endpoint: 'signup.php');
    } on TimeoutException {
      return {'error': true, 'message': 'Signup request timed out'};
    } on SocketException {
      return {'error': true, 'message': 'Unable to reach server while registering clinic'};
    } catch (e) {
      return {'error': true, 'message': 'Exception: $e'};
    }
  }

  Future<Map<String, dynamic>> fetchClinicDashboard(int clinicAccountId) async {
    final uri = Uri.parse('${phpapi}get_clinic_dashboard.php').replace(queryParameters: {
      'account_id': clinicAccountId.toString(),
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_clinic_dashboard.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load clinic dashboard').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Clinic dashboard request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading clinic dashboard');
    }
  }

  Future<Map<String, dynamic>> clinicRegisterMember(int clinicAccountId, Map<String, dynamic> payload) async {
    final uri = Uri.parse('${phpapi}clinic_register_member.php');
    final body = <String, String>{
      'clinic_account_id': clinicAccountId.toString(),
      'role': (payload['role'] ?? '').toString(),
      'email': (payload['email'] ?? '').toString(),
      'password': (payload['password'] ?? '').toString(),
      'name': (payload['name'] ?? '').toString(),
      'phone': (payload['phone'] ?? '').toString(),
      'birth_date': (payload['birth_date'] ?? '').toString(),
      'specialization': (payload['specialization'] ?? '').toString(),
    };
    if (payload['therapist_id'] != null) {
      body['therapist_id'] = payload['therapist_id'].toString();
    }

    try {
      final response = await http.post(uri, body: body).timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'clinic_register_member.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to create member').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Member creation request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while creating member');
    }
  }

  Future<Map<String, dynamic>> clinicUpdateProfile({
    required int clinicAccountId,
    required String name,
    required String address,
    required String phone,
  }) async {
    final uri = Uri.parse('${phpapi}clinic_update_profile.php');
    try {
      final response = await http.post(uri, body: {
        'clinic_account_id': clinicAccountId.toString(),
        'name': name,
        'address': address,
        'phone': phone,
      }).timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'clinic_update_profile.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to update clinic profile').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Profile update timed out');
    } on SocketException {
      throw Exception('Unable to reach server while updating clinic profile');
    }
  }

  Future<Map<String, dynamic>> createSubscription({
    required int clinicAccountId,
    required String plan,
  }) async {
    final uri = Uri.parse('${phpapi}create_subscription.php');
    try {
      final response = await http.post(uri, body: {
        'clinic_account_id': clinicAccountId.toString(),
        'plan': plan,
      }).timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'create_subscription.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to create subscription').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Subscription request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while creating subscription');
    }
  }

  Future<Map<String, dynamic>> verifySubscriptionPayment({
    required int clinicAccountId,
    required String reference,
  }) async {
    final uri = Uri.parse('${phpapi}verify_subscription_payment.php');
    try {
      final response = await http.post(uri, body: {
        'clinic_account_id': clinicAccountId.toString(),
        'reference': reference,
      }).timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'verify_subscription_payment.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to verify payment').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Payment verification timed out');
    } on SocketException {
      throw Exception('Unable to reach server while verifying payment');
    }
  }

  Future<Map<String, dynamic>> clinicDeleteMember({
    required int clinicAccountId,
    required int memberAccountId,
    required String memberRole,
  }) async {
    final uri = Uri.parse('${phpapi}clinic_delete_member.php');
    try {
      final response = await http.post(uri, body: {
        'clinic_account_id': clinicAccountId.toString(),
        'member_account_id': memberAccountId.toString(),
        'member_role': memberRole,
      }).timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'clinic_delete_member.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to delete member').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Delete member request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while deleting member');
    }
  }

  Future<Map<String, dynamic>> fetchAdminDashboard(int adminAccountId) async {
    final uri = Uri.parse('${phpapi}get_admin_dashboard.php').replace(queryParameters: {
      'account_id': adminAccountId.toString(),
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_admin_dashboard.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load admin dashboard').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Admin dashboard request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading admin dashboard');
    }
  }

  Future<Map<String, dynamic>> adminSetClinicStatus({
    required int adminAccountId,
    required int clinicAccountId,
    required bool isActive,
  }) async {
    final uri = Uri.parse('${phpapi}admin_set_clinic_status.php');
    try {
      final response = await http.post(uri, body: {
        'admin_account_id': adminAccountId.toString(),
        'clinic_account_id': clinicAccountId.toString(),
        'is_active': isActive ? '1' : '0',
      }).timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'admin_set_clinic_status.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to update clinic status').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Clinic approval request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while updating clinic status');
    }
  }

  Future<Map<String, dynamic>> adminDeleteAccount({
    required int adminAccountId,
    required int targetAccountId,
  }) async {
    final uri = Uri.parse('${phpapi}admin_update_account.php');
    try {
      final response = await http.post(uri, body: {
        'admin_account_id': adminAccountId.toString(),
        'target_account_id': targetAccountId.toString(),
        'action': 'delete',
      }).timeout(const Duration(seconds: 14));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'admin_update_account.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to delete account').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Delete account request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while deleting account');
    }
  }

  Future<List<Clinic>> fetchClinics() async {
    final uri = Uri.parse("${phpapi}get_clinics.php");

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception("Server error: ${response.statusCode}");
      }

      final dynamic decoded = json.decode(response.body);
      List<dynamic> clinicList = [];

      if (decoded is List) {
        clinicList = decoded;
      } else if (decoded is Map<String, dynamic>) {
        if (decoded['error'] == true) {
          throw Exception(decoded['message'] ?? 'Failed to fetch clinics');
        }
        if (decoded['clinics'] is List) {
          clinicList = decoded['clinics'] as List<dynamic>;
        }
      }

      return clinicList
          .whereType<Map>()
          .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
          .map((jsonMap) => Clinic.fromJson({
                'id': int.tryParse(jsonMap['id'].toString()) ?? 0,
                'account_id': int.tryParse((jsonMap['account_id'] ?? 0).toString()) ?? 0,
                'name': (jsonMap['name'] ?? '').toString(),
                'address': jsonMap['address']?.toString(),
                'phone': jsonMap['phone']?.toString(),
              }))
          .where((clinic) => clinic.id > 0 && clinic.name.isNotEmpty)
          .toList();
    } on TimeoutException {
      throw Exception('Clinic request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading clinics');
    }
  }

  Future<Map<String, dynamic>> fetchPatientHome(int accountId, {String filter = 'today'}) async {
    return fetchPatientHomeMinimal(accountId, filter: filter);
  }

  Future<Map<String, dynamic>> fetchPatientHomeMinimal(int accountId, {String filter = 'all'}) async {
    final uri = Uri.parse("${phpapi}get_patient_videos_home.php").replace(queryParameters: {
      'account_id': accountId.toString(),
      'filter': filter,
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        final preview = _responsePreview(response.body);
        throw Exception('Server error ${response.statusCode}. Response: $preview');
      }

      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_patient_videos_home.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load homepage').toString());
      }

      final summaryRaw = decoded['summary'];
      final accessRaw = decoded['access'];
      final exercisesRaw = decoded['exercises'];
      final summary = summaryRaw is Map<String, dynamic> ? summaryRaw : <String, dynamic>{};
      final access = accessRaw is Map<String, dynamic> ? accessRaw : <String, dynamic>{};

      final exercises = exercisesRaw is List
          ? exercisesRaw.whereType<Map>().map((e) {
              final map = e.map((key, value) => MapEntry(key.toString(), value));
              final status = (map['status'] ?? 'pending').toString();
              final isCompleted = status.toLowerCase() == 'completed' || status.toLowerCase() == 'done';

              return {
                'id': int.tryParse((map['id'] ?? 0).toString()) ?? 0,
                'ppid': int.tryParse((map['ppid'] ?? map['id'] ?? 0).toString()) ?? 0,
                'exercise_id': int.tryParse((map['exercise_id'] ?? map['id'] ?? 0).toString()) ?? 0,
                'name': (map['name'] ?? 'Exercise').toString(),
                'description': (map['description'] ?? '').toString(),
                'video_url': (map['video_url'] ?? '').toString(),
                'sets': int.tryParse((map['sets'] ?? 0).toString()) ?? 0,
                'reps': int.tryParse((map['reps'] ?? 0).toString()) ?? 0,
                'assigned_date': (map['assigned_date'] ?? '').toString(),
                'assigned_by_name': (map['assigned_by_name'] ?? '').toString(),
                'status': status,
                'is_completed': isCompleted,
                'reps_done': map['reps_done'] != null
                    ? int.tryParse(map['reps_done'].toString())
                    : null,
                'pain_level': map['pain_level'] != null
                    ? int.tryParse(map['pain_level'].toString())
                    : null,
                'progress_notes': map['progress_notes']?.toString(),
                'last_report_date': map['last_report_date']?.toString(),
                'completion_percent': int.tryParse((map['completion_percent'] ?? 0).toString()) ?? 0,
                'ai_exercise': map['ai_exercise']?.toString(),
                'side': map['side']?.toString(),
                'body_region': map['body_region']?.toString(),
                'target_deg': double.tryParse((map['target_deg'] ?? '').toString()),
                'usual_lift_deg': double.tryParse((map['usual_lift_deg'] ?? '').toString()),
              };
            }).toList()
          : <Map<String, dynamic>>[];

      final total = int.tryParse((summary['total'] ?? exercises.length).toString()) ?? exercises.length;
      final completedFromSummary = int.tryParse((summary['completed'] ?? '').toString());
      final completed = completedFromSummary ?? exercises.where((e) => e['is_completed'] == true).length;
      final percent = total == 0 ? 0 : ((completed * 100) / total).round();

      final canRecordVideo =
          access['can_record_video'] == true ||
          access['can_record_video'] == 1 ||
          access['can_record_video'].toString() == '1';

      return {
        'summary': {
          'total': total,
          'completed': completed,
          'percent': int.tryParse((summary['percent'] ?? percent).toString()) ?? percent,
          'filter': (summary['filter'] ?? filter).toString(),
        },
        'access': {
          'has_active_subscription': access['has_active_subscription'] == true || access['has_active_subscription'] == 1,
          // Safe default: when access payload is missing/corrupted, keep recording locked.
          'can_record_video': canRecordVideo,
        },
        'exercises': exercises,
      };
    } on TimeoutException {
      throw Exception('Homepage request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading homepage');
    }
  }

  Future<Map<String, dynamic>> fetchPatientProfileTab(int accountId) async {
    final uri = Uri.parse("${phpapi}get_patient_profile_tab.php").replace(queryParameters: {
      'account_id': accountId.toString(),
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_patient_profile_tab.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load profile').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Profile request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading profile');
    }
  }

  Future<Map<String, dynamic>> updatePatientProfileTab({
    required int accountId,
    required String name,
    required String phone,
    String? password,
  }) async {
    final uri = Uri.parse("${phpapi}update_patient_profile_tab.php");
    final body = <String, String>{
      'account_id': accountId.toString(),
      'name': name,
      'phone': phone,
    };
    if (password != null && password.trim().isNotEmpty) {
      body['password'] = password.trim();
    }

    try {
      final response = await http.post(uri, body: body).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'update_patient_profile_tab.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to update profile').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Update request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while updating profile');
    }
  }

  Future<Map<String, dynamic>> uploadPatientPhoto({
    required int accountId,
    required File photo,
  }) async {
    final uri = Uri.parse("${phpapi}upload_profile_photo.php");
    final request = http.MultipartRequest('POST', uri);
    request.fields['account_id'] = accountId.toString();
    request.files.add(await http.MultipartFile.fromPath('photo', photo.path));

    try {
      final response = await request.send().timeout(const Duration(seconds: 18));
      final body = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final decoded = _decodeJsonMapResponse(body, endpoint: 'upload_profile_photo.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to upload photo').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Photo upload timed out');
    } on SocketException {
      throw Exception('Unable to reach server while uploading photo');
    }
  }

  Future<Map<String, dynamic>> submitComplaintForm({
    required int accountId,
    required String description,
    required String symptoms,
  }) async {
    final uri = Uri.parse("${phpapi}submit_complaint_form.php");

    try {
      final response = await http.post(uri, body: {
        'account_id': accountId.toString(),
        'description': description,
        'symptoms': symptoms,
      }).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'submit_complaint_form.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to submit complaint').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Complaint request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while submitting complaint');
    }
  }

  Future<List<Map<String, dynamic>>> fetchClinicComplaints(int accountId) async {
    final uri = Uri.parse('${phpapi}get_clinic_complaints.php').replace(queryParameters: {
      'account_id': accountId.toString(),
    });
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_clinic_complaints.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load complaints').toString());
      }
      final raw = decoded['complaints'];
      if (raw is! List) return <Map<String, dynamic>>[];
      return raw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
    } on TimeoutException {
      throw Exception('Complaints request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading complaints');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPhysioComplaints(int accountId) async {
    final uri = Uri.parse('${phpapi}get_physio_complaints.php').replace(queryParameters: {
      'account_id': accountId.toString(),
    });
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_physio_complaints.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load complaints').toString());
      }
      final raw = decoded['complaints'];
      if (raw is! List) return <Map<String, dynamic>>[];
      return raw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList();
    } on TimeoutException {
      throw Exception('Complaints request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading complaints');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPatientMessages(int accountId) async {
    final uri = Uri.parse("${phpapi}get_patient_messages.php").replace(queryParameters: {
      'account_id': accountId.toString(),
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_patient_messages.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load messages').toString());
      }

      final messagesRaw = decoded['messages'];
      if (messagesRaw is! List) {
        return <Map<String, dynamic>>[];
      }

      return messagesRaw.whereType<Map>().map((e) {
        final map = e.map((key, value) => MapEntry(key.toString(), value));
        return <String, dynamic>{
          'id': int.tryParse((map['id'] ?? 0).toString()) ?? 0,
          'sender_id': int.tryParse((map['sender_id'] ?? 0).toString()) ?? 0,
          'receiver_id': int.tryParse((map['receiver_id'] ?? 0).toString()) ?? 0,
          'content': (map['content'] ?? '').toString(),
          'sent_at': (map['sent_at'] ?? '').toString(),
          'is_read': map['is_read'] == true || map['is_read'] == 1,
          'is_mine': map['is_mine'] == true || map['is_mine'] == 1,
          'sender_name': (map['sender_name'] ?? '').toString(),
        };
      }).toList();
    } on TimeoutException {
      throw Exception('Messages request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading messages');
    }
  }

  Future<Map<String, dynamic>> sendPatientMessage({
    required int accountId,
    required String content,
  }) async {
    final uri = Uri.parse("${phpapi}send_patient_message.php");

    try {
      final response = await http.post(uri, body: {
        'account_id': accountId.toString(),
        'content': content,
      }).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'send_patient_message.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to send message').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Send message request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while sending message');
    }
  }



  Future<Map<String, dynamic>> submitProgressReport({
    required int accountId,
    int? exerciseId,
    int? patientExerciseId,
    required int repsDone,
    int? painLevel,
    String? notes,
  }) async {
    final uri = Uri.parse("${phpapi}submit_progress_report.php");
    final body = <String, String>{
      'account_id': accountId.toString(),
      'reps_done': repsDone.toString(),
    };
    if (exerciseId != null && exerciseId > 0) {
      body['exercise_id'] = exerciseId.toString();
    }
    if (patientExerciseId != null && patientExerciseId > 0) {
      body['patient_exercise_id'] = patientExerciseId.toString();
    }
    if (painLevel != null) body['pain_level'] = painLevel.toString();
    if (notes != null && notes.trim().isNotEmpty) body['notes'] = notes.trim();

    try {
      final response = await http.post(uri, body: body).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'submit_progress_report.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to submit progress').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Progress report request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while submitting progress report');
    }
  }

  /// A finished live camera set: adds the reps to today's progress report and stores the rep-by-rep analysis
  /// for the physiotherapist (submit_live_session.php). Returns the progress report id.
  Future<Map<String, dynamic>> submitLiveSession({
    required int accountId,
    required int patientExerciseId,
    required int repsDone,
    required String notes,
    required String analysis,
    required double score,
    String setUid = '',
    int good = 0,
    int mistakes = 0,
    int unsure = 0,
    int belowTarget = 0,
    int wrongSide = 0,
    List<Map<String, Object?>> painEvents = const [],
    List<Map<String, Object?>> reps = const [],
  }) async {
    final uri = Uri.parse("${phpapi}submit_live_session.php");
    final body = <String, String>{
      'account_id': accountId.toString(),
      'patient_exercise_id': patientExerciseId.toString(),
      'reps_done': repsDone.toString(),
      'notes': notes,
      'analysis': analysis,
      'score': score.toStringAsFixed(1),
      // a re-sent set (same set_uid) is recognised by the server and not counted twice
      if (setUid.isNotEmpty) 'set_uid': setUid,
      'good': good.toString(),
      'mistakes': mistakes.toString(),
      'unsure': unsure.toString(),
      'below_target': belowTarget.toString(),
      'wrong_side': wrongSide.toString(),
      'pain_events': json.encode(painEvents),
      // one entry per rep (label, status, confidence, e4 peak angle and target): the physiotherapist's progress
      if (reps.isNotEmpty) 'reps': json.encode(reps),
    };
    try {
      final response = await http.post(uri, body: body).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'submit_live_session.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to save the set').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Saving the set timed out');
    } on SocketException {
      throw Exception('Unable to reach the server to save the set');
    }
  }

  /// The feedback of one session (a progress report: its live sets with counts, pain, score and every rep), by
  /// [progressId], or by the assignment [patientExerciseId] and its [date] (YYYY-MM-DD). For the patient or their
  /// physiotherapist.
  Future<Map<String, dynamic>> fetchSessionFeedback({
    required int accountId,
    int? progressId,
    int? patientExerciseId,
    String? date,
  }) async {
    final uri = Uri.parse("${phpapi}get_session_feedback.php").replace(queryParameters: {
      'account_id': accountId.toString(),
      if (progressId != null && progressId > 0) 'progress_id': progressId.toString(),
      if (patientExerciseId != null && patientExerciseId > 0) 'patient_exercise_id': patientExerciseId.toString(),
      if (date != null) 'date': date,
    });
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_session_feedback.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load the session').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Loading the session timed out');
    } on SocketException {
      throw Exception('Unable to reach the server to load the session');
    }
  }

  /// Pain level (0-10) of a progress report that was just sent.
  Future<void> setLiveSessionPain({
    required int accountId,
    required int progressId,
    required int painLevel,
    String setUid = '',
  }) async {
    final uri = Uri.parse("${phpapi}submit_live_session.php");
    try {
      final response = await http.post(uri, body: {
        'account_id': accountId.toString(),
        'progress_id': progressId.toString(),
        'pain_level': painLevel.toString(),
        if (setUid.isNotEmpty) 'set_uid': setUid,
      }).timeout(const Duration(seconds: 12));
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'submit_live_session.php');
      if (response.statusCode != 200 || decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to save the pain level').toString());
      }
    } on TimeoutException {
      throw Exception('Saving the pain level timed out');
    } on SocketException {
      throw Exception('Unable to reach the server to save the pain level');
    }
  }

  Future<Map<String, dynamic>> uploadAiFeedbackVideo({
    required int accountId,
    required int progressReportId,
    required File videoFile,
    String? analysis,
    double? score,
  }) async {
    final uri = Uri.parse('${phpapi}upload_ai_feedback_video.php');
    final request = http.MultipartRequest('POST', uri)
      ..fields['account_id'] = accountId.toString()
      ..fields['progressreport_id'] = progressReportId.toString();

    if (analysis != null && analysis.trim().isNotEmpty) {
      request.fields['analysis'] = analysis.trim();
    }
    if (score != null) {
      request.fields['score'] = score.toString();
    }

    request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));

    try {
      final streamed = await request.send().timeout(const Duration(seconds: 35));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'upload_ai_feedback_video.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to upload AI feedback video').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('AI feedback upload request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while uploading AI feedback video');
    }
  }

  Future<Map<String, dynamic>> fetchWeeklyCompletion(int accountId) async {
    final uri = Uri.parse("${phpapi}get_weekly_completion.php").replace(queryParameters: {
      'account_id': accountId.toString(),
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_weekly_completion.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load weekly completion').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Weekly completion request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading weekly completion');
    }
  }

  Future<Map<String, dynamic>> fetchPhysioHome(int accountId) async {
    final uri = Uri.parse("${phpapi}get_physio_home.php").replace(queryParameters: {
      'account_id': accountId.toString(),
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_physio_home.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load physiotherapist home').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Physiotherapist home request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading physiotherapist home');
    }
  }

  Future<Map<String, dynamic>> fetchPhysioPatients(int accountId) async {
    final uri = Uri.parse("${phpapi}get_physio_patients.php").replace(queryParameters: {
      'account_id': accountId.toString(),
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_physio_patients.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load patients').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Patients request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading patients');
    }
  }

  Future<Map<String, dynamic>> fetchPhysioPatientDetails({
    required int accountId,
    required int patientId,
  }) async {
    final uri = Uri.parse("${phpapi}get_physio_patient_details.php").replace(queryParameters: {
      'account_id': accountId.toString(),
      'patient_id': patientId.toString(),
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_physio_patient_details.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load patient details').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Patient details request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading patient details');
    }
  }

  Future<Map<String, dynamic>> assignPatientExerciseByPhysio({
    required int accountId,
    required int patientId,
    required int exerciseId,
    required int sets,
    required int reps,
    String? aiExercise,
    String? side,
    double? targetDeg,
    DateTime? startDate,
    DateTime? endDate,
    String? frequency,
  }) async {
    final uri = Uri.parse("${phpapi}assign_patient_exercise.php");
    final body = <String, String>{
      'account_id': accountId.toString(),
      'patient_id': patientId.toString(),
      'exercise_id': exerciseId.toString(),
      'sets': sets.toString(),
      'reps': reps.toString(),
      if (startDate != null) 'start_date': DateFormat('yyyy-MM-dd').format(startDate),
      if (endDate != null) 'end_date': DateFormat('yyyy-MM-dd').format(endDate),
      if (frequency != null && frequency.isNotEmpty) 'frequency': frequency,
      // live camera tracking chosen by the physiotherapist (e1..e4 + the arm / lifted leg), or none
      if (aiExercise != null && aiExercise.isNotEmpty) 'ai_exercise': aiExercise,
      if (aiExercise != null && aiExercise.isNotEmpty && side != null) 'side': side,
      // e4: the target lift angle (degrees); not sent = not set
      if (aiExercise == 'e4' && targetDeg != null) 'target_deg': targetDeg.toStringAsFixed(1),
    };

    try {
      final response = await http.post(uri, body: body).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'assign_patient_exercise.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to assign exercise').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Assign exercise request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while assigning exercise');
    }
  }

  Future<Map<String, dynamic>> removePatientExerciseByPhysio({
    required int accountId,
    required int patientExerciseId,
    String? prescriptionId,
  }) async {
    final uri = Uri.parse("${phpapi}remove_patient_exercise.php");
    final body = <String, String>{
      'account_id': accountId.toString(),
      'patient_exercise_id': patientExerciseId.toString(),
      if (prescriptionId != null && prescriptionId.isNotEmpty) 'prescription_id': prescriptionId,
    };

    try {
      final response = await http.post(uri, body: body).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'remove_patient_exercise.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to remove exercise').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Remove exercise request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while removing exercise');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPhysioAiFeedback({
    required int accountId,
    required int patientId,
  }) async {
    final uri = Uri.parse("${phpapi}get_physio_ai_feedback.php").replace(queryParameters: {
      'account_id': accountId.toString(),
      'patient_id': patientId.toString(),
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_physio_ai_feedback.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load AI feedback').toString());
      }

      final feedbackRaw = decoded['feedback'];
      if (feedbackRaw is! List) {
        return <Map<String, dynamic>>[];
      }

      return feedbackRaw.whereType<Map>().map((e) {
        final map = e.map((key, value) => MapEntry(key.toString(), value));
        return <String, dynamic>{
          'id': int.tryParse((map['id'] ?? 0).toString()) ?? 0,
          'progress_id': int.tryParse((map['progress_id'] ?? 0).toString()) ?? 0,
          'exercise_id': int.tryParse((map['exercise_id'] ?? 0).toString()) ?? 0,
          'exercise_name': (map['exercise_name'] ?? '').toString(),
          'ai_exercise': map['ai_exercise']?.toString(),
          'score': double.tryParse((map['score'] ?? '').toString()),
          'analysis': (map['analysis'] ?? '').toString(),
          'progress_date': (map['progress_date'] ?? '').toString(),
          'generated_at': (map['generated_at'] ?? '').toString(),
        };
      }).toList();
    } on TimeoutException {
      throw Exception('AI feedback request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading AI feedback');
    }
  }

  Future<Map<String, dynamic>> fetchPhysioProfileTab(int accountId) async {
    final uri = Uri.parse("${phpapi}get_physio_profile_tab.php").replace(queryParameters: {
      'account_id': accountId.toString(),
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_physio_profile_tab.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load profile').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Profile request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading profile');
    }
  }

  Future<Map<String, dynamic>> updatePhysioProfileTab({
    required int accountId,
    required String name,
    required String phone,
    String specialization = '',
    String? password,
  }) async {
    final uri = Uri.parse("${phpapi}update_physio_profile_tab.php");
    final body = <String, String>{
      'account_id': accountId.toString(),
      'name': name,
      'phone': phone,
      'specialization': specialization,
    };
    if (password != null && password.trim().isNotEmpty) {
      body['password'] = password.trim();
    }

    try {
      final response = await http.post(uri, body: body).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'update_physio_profile_tab.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to update profile').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Update request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while updating profile');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPhysioMessages({
    required int accountId,
    required int patientAccountId,
  }) async {
    final uri = Uri.parse("${phpapi}get_physio_messages.php").replace(queryParameters: {
      'account_id': accountId.toString(),
      'patient_account_id': patientAccountId.toString(),
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'get_physio_messages.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to load messages').toString());
      }

      final messagesRaw = decoded['messages'];
      if (messagesRaw is! List) {
        return <Map<String, dynamic>>[];
      }

      return messagesRaw.whereType<Map>().map((e) {
        final map = e.map((key, value) => MapEntry(key.toString(), value));
        return <String, dynamic>{
          'id': int.tryParse((map['id'] ?? 0).toString()) ?? 0,
          'sender_id': int.tryParse((map['sender_id'] ?? 0).toString()) ?? 0,
          'receiver_id': int.tryParse((map['receiver_id'] ?? 0).toString()) ?? 0,
          'content': (map['content'] ?? '').toString(),
          'sent_at': (map['sent_at'] ?? '').toString(),
          'is_read': map['is_read'] == true || map['is_read'] == 1,
          'is_mine': map['is_mine'] == true || map['is_mine'] == 1,
          'sender_name': (map['sender_name'] ?? '').toString(),
        };
      }).toList();
    } on TimeoutException {
      throw Exception('Messages request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while loading messages');
    }
  }

  Future<Map<String, dynamic>> sendPhysioMessage({
    required int accountId,
    required int patientAccountId,
    required String content,
  }) async {
    final uri = Uri.parse("${phpapi}send_physio_message.php");

    try {
      final response = await http.post(uri, body: {
        'account_id': accountId.toString(),
        'patient_account_id': patientAccountId.toString(),
        'content': content,
      }).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final decoded = _decodeJsonMapResponse(response.body, endpoint: 'send_physio_message.php');
      if (decoded['error'] == true) {
        throw Exception((decoded['message'] ?? 'Failed to send message').toString());
      }
      return decoded;
    } on TimeoutException {
      throw Exception('Send message request timed out');
    } on SocketException {
      throw Exception('Unable to reach server while sending message');
    }
  }

  Map<String, dynamic> _decodeJsonMapResponse(String body, {required String endpoint}) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw Exception('Empty response from $endpoint');
    }

    String candidate = trimmed;
    final firstObject = trimmed.indexOf('{');
    final firstArray = trimmed.indexOf('[');
    int firstJson = -1;
    if (firstObject >= 0 && firstArray >= 0) {
      firstJson = firstObject < firstArray ? firstObject : firstArray;
    } else if (firstObject >= 0) {
      firstJson = firstObject;
    } else if (firstArray >= 0) {
      firstJson = firstArray;
    }
    if (firstJson > 0) {
      candidate = trimmed.substring(firstJson);
    }

    try {
      final decoded = json.decode(candidate);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected JSON structure');
      }
      return decoded;
    } catch (_) {
      throw Exception('Invalid JSON from $endpoint. Response starts with: ${_responsePreview(trimmed)}');
    }
  }

  String _responsePreview(String body) {
    final cleaned = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 180) {
      return cleaned;
    }
    return '${cleaned.substring(0, 180)}...';
  }
}





