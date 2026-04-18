// ========================================
// GigsCourt - All Services (Firebase + Supabase + ImageKit + Paystack)
// ========================================

import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';

// ========== SINGLETON SERVICES ==========
class AppServices {
  static final AppServices _instance = AppServices._internal();
  factory AppServices() => _instance;
  AppServices._internal();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  final SupabaseClient supabase = Supabase.instance.client;

  User? get currentUser => auth.currentUser;
  String get currentUserId => currentUser?.uid ?? '';
}

final services = AppServices();

// ========== IMAGEKIT CONFIG ==========
const String imagekitUrl = 'https://ik.imagekit.io/Theprimestar';
const String imagekitPublicKey = 'public_hwM9hldZI+DqFY/pncPQCA5VRWo=';

// ========== PAYSTACK CONFIG ==========
const String paystackPublicKey = 'pk_test_4f6ae42964ab8da60e2f1c77cfb6fe1cd30806cc';

// ========== HELPER FUNCTIONS ==========
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()}m away';
  return '${(meters / 1000).toStringAsFixed(1)}km away';
}

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double r = 6371000;
  final double phi1 = lat1 * math.pi / 180;
  final double phi2 = lat2 * math.pi / 180;
  final double deltaPhi = (lat2 - lat1) * math.pi / 180;
  final double deltaLambda = (lon2 - lon1) * math.pi / 180;
  
  final double a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
      math.cos(phi1) * math.cos(phi2) *
      math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  
  return r * c;
}

String getOptimizedImageUrl(String? url, {int width = 100, int height = 100}) {
  if (url == null || url.isEmpty) return '';
  if (url.contains('ui-avatars.com')) return url;
  return '$url?tr=f-webp,w-$width,h-$height,c-at_max,cache-control=public,max-age=31536000';
}

// ========== AUTH SERVICE ==========
class AuthService {
  Future<User?> signUp(String email, String password) async {
    try {
      final userCred = await services.auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCred.user?.sendEmailVerification();
      return userCred.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      final userCred = await services.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCred.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await services.auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await services.auth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    await services.auth.currentUser?.updateDisplayName(displayName);
    await services.auth.currentUser?.updatePhotoURL(photoURL);
  }

  Stream<User?> get authStateChanges => services.auth.authStateChanges();
}

// ========== FIRESTORE SERVICE ==========
class FirestoreService {
  CollectionReference get usersRef => services.firestore.collection('users');
  CollectionReference get chatsRef => services.firestore.collection('chats');
  CollectionReference get transactionsRef => services.firestore.collection('transactions');
  CollectionReference get adminStatsRef => services.firestore.collection('admin_stats');

  // User Methods
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await usersRef.doc(uid).get();
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc.data() as Map<String, dynamic>, uid);
    } catch (e) {
      return null;
    }
  }

  Future<void> createUserProfile(UserModel user) async {
    await usersRef.doc(user.uid).set(user.toFirestore());
  }

  Future<void> updateUser(String uid, Map<String, dynamic> updates) async {
    await usersRef.doc(uid).update({
      ...updates,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<UserModel?> userStream(String uid) {
    return usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc.data() as Map<String, dynamic>, uid);
    });
  }

  // Batch Fetch Users (max 30 at a time)
  Future<Map<String, UserModel>> batchFetchUsers(List<String> userIds) async {
    final Map<String, UserModel> result = {};
    if (userIds.isEmpty) return result;

    final batchSize = 30;
    for (int i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.sublist(i, i + batchSize > userIds.length ? userIds.length : i + batchSize);
      final futures = batch.map((uid) => getUser(uid));
      final users = await Future.wait(futures);
      
      for (int j = 0; j < batch.length; j++) {
        final user = users[j];
        if (user != null) result[batch[j]] = user;
      }
    }
    return result;
  }

  // Chat Methods
  Stream<List<ChatModel>> chatsStream(String userId) {
    return chatsRef
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Stream<List<MessageModel>> messagesStream(String chatId) {
    return chatsRef
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs.map((doc) {
        return MessageModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      return messages.reversed.toList();
    });
  }

  // Gig Methods
  Stream<GigModel?> pendingGigStream(String chatId) {
    return chatsRef
        .doc(chatId)
        .collection('gigs')
        .where('status', isEqualTo: 'pending_review')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return GigModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  Future<GigModel?> getPendingGig(String chatId) async {
    final snapshot = await chatsRef
        .doc(chatId)
        .collection('gigs')
        .where('status', isEqualTo: 'pending_review')
        .limit(1)
        .get();
    
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return GigModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<String> createGig(String chatId, String providerId, String clientId) async {
    final gigRef = await chatsRef.doc(chatId).collection('gigs').add({
      'providerId': providerId,
      'clientId': clientId,
      'status': 'pending_review',
      'registeredAt': DateTime.now().toIso8601String(),
      'completedAt': null,
      'cancelledAt': null,
      'cancelledBy': null,
      'review': null,
    });
    
    await chatsRef.doc(chatId).update({
      'pendingReview': true,
      'pendingGigId': gigRef.id,
    });
    
    return gigRef.id;
  }

  // Notification Methods
  Future<void> updateUnreadCount(String chatId, String userId, int increment) async {
    await chatsRef.doc(chatId).update({
      'unreadCount.$userId': FieldValue.increment(increment),
    });
  }

  // Transaction Methods
  Future<void> addTransaction(TransactionModel transaction) async {
    await transactionsRef.add({
      'userId': transaction.userId,
      'type': transaction.type,
      'credits': transaction.credits,
      'amount': transaction.amount,
      'reference': transaction.reference,
      'createdAt': transaction.createdAt.toIso8601String(),
    });
  }

  Stream<List<TransactionModel>> transactionsStream(String userId) {
    return transactionsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TransactionModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Admin Stats
  Future<Map<String, dynamic>> getAdminStats() async {
    final doc = await adminStatsRef.doc('stats').get();
    if (!doc.exists) return {};
    return doc.data() as Map<String, dynamic>;
  }

  Future<void> incrementAdminStats(String field, {int amount = 1}) async {
    final statsRef = adminStatsRef.doc('stats');
    await services.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(statsRef);
      if (!snapshot.exists) {
        transaction.set(statsRef, {
          field: amount,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      } else {
        transaction.update(statsRef, {
          field: FieldValue.increment(amount),
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      }
    });
  }
}

// ========== SUPABASE SERVICE ==========
class SupabaseService {
  // Home Feed - Cursor based pagination
  Future<List<ProviderLocation>> getHomeFeedProviders({
    required double lat,
    required double lng,
    int limit = 20,
    double? cursorDistance,
    String? cursorUserId,
  }) async {
    try {
      final data = await services.supabase.rpc('get_home_feed_providers', params: {
        'p_current_lat': lat,
        'p_current_lng': lng,
        'p_limit': limit,
        'p_cursor_distance': cursorDistance,
        'p_cursor_user_id': cursorUserId,
      });
      
      return (data as List).map((item) => ProviderLocation.fromSupabase(item)).toList();
    } catch (e) {
      return [];
    }
  }

  // Search Providers
  Future<List<ProviderLocation>> searchProviders({
    required double lat,
    required double lng,
    required double radiusKm,
    String? serviceFilter,
    int limit = 20,
    double? cursorDistance,
    String? cursorUserId,
  }) async {
    try {
      final data = await services.supabase.rpc('search_providers', params: {
        'p_current_lat': lat,
        'p_current_lng': lng,
        'p_radius_km': radiusKm,
        'p_service_filter': serviceFilter,
        'p_limit': limit,
        'p_cursor_distance': cursorDistance,
        'p_cursor_user_id': cursorUserId,
      });
      
      return (data as List).map((item) => ProviderLocation.fromSupabase(item)).toList();
    } catch (e) {
      return [];
    }
  }

  // Update provider location
  Future<void> upsertProviderLocation({
    required String userId,
    required double lat,
    required double lng,
    required String services,
  }) async {
    try {
      await services.supabase.from('provider_locations').upsert({
        'user_id': userId,
        'lat': lat,
        'lng': lng,
        'location': 'POINT($lng $lat)',
        'services': services,
        'rating': 0,
        'gig_count': 0,
        'last_gig_date': null,
      }, onConflict: 'user_id');
    } catch (e) {
      // Silent fail - not critical
    }
  }

  // Update last gig date
  Future<void> updateLastGigDate(String userId) async {
    try {
      await services.supabase
          .from('provider_locations')
          .update({'last_gig_date': DateTime.now().toIso8601String()})
          .eq('user_id', userId);
    } catch (e) {
      // Silent fail
    }
  }

  // Get service categories
  Future<List<ServiceCategory>> getServiceCategories() async {
    try {
      final data = await services.supabase
          .from('service_categories')
          .select()
          .order('display_order');
      
      return (data as List).map((item) => ServiceCategory.fromSupabase(item)).toList();
    } catch (e) {
      return [];
    }
  }

  // Get preset services
  Future<List<PresetService>> getPresetServices() async {
    try {
      final data = await services.supabase
          .from('preset_services')
          .select()
          .eq('is_active', true);
      
      return (data as List).map((item) => PresetService.fromSupabase(item)).toList();
    } catch (e) {
      return [];
    }
  }

  // Create service request
  Future<void> createServiceRequest(String userId, String email, String serviceName) async {
    try {
      await services.supabase.from('service_requests').insert({
        'user_id': userId,
        'user_email': email,
        'requested_service': serviceName,
        'status': 'pending',
      });
    } catch (e) {
      // Silent fail
    }
  }

  // Get pending service requests (admin)
  Future<List<Map<String, dynamic>>> getPendingServiceRequests() async {
    try {
      final data = await services.supabase
          .from('service_requests')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      
      return data as List<Map<String, dynamic>>;
    } catch (e) {
      return [];
    }
  }

  // Process service request (admin)
  Future<Map<String, dynamic>> processServiceRequest({
    required String requestId,
    required String action,
    String? editedName,
  }) async {
    try {
      final data = await services.supabase.rpc('admin_process_service_request', params: {
        'p_request_id': requestId,
        'p_action': action,
        'p_edited_name': editedName,
      });
      return data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

// ========== IMAGEKIT SERVICE ==========
class ImageKitService {
  // Get auth parameters from your Vercel endpoint
  Future<Map<String, dynamic>> getAuthParams() async {
    try {
      final response = await http.get(
        Uri.parse('https://gigscourt.vercel.app/api/imagekit-auth'),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // Upload image
  Future<String?> uploadImage({
    required String filePath,
    required String fileName,
    String folder = 'profiles',
  }) async {
    try {
      final authParams = await getAuthParams();
      if (authParams.isEmpty) return null;
      
      final uri = Uri.parse('https://upload.imagekit.io/api/v1/files/upload');
      final request = http.MultipartRequest('POST', uri);
      
      request.fields['fileName'] = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      request.fields['folder'] = '/GigsCourt/$folder';
      request.fields['useUniqueFileName'] = 'true';
      request.fields['publicKey'] = authParams['publicKey'] ?? '';
      request.fields['signature'] = authParams['signature'] ?? '';
      request.fields['token'] = authParams['token'] ?? '';
      request.fields['expire'] = authParams['expire']?.toString() ?? '';
      
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final json = jsonDecode(responseData);
        return json['url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

// ========== PAYSTACK SERVICE ==========
class PaystackService {
  void openPaystackCheckout({
    required String email,
    required int amount,
    required Function(String reference) onSuccess,
  }) {
    // Convert amount to kobo (Paystack uses kobo)
    final amountInKobo = amount * 100;
    
    // Build Paystack URL
    final url = 'https://checkout.paystack.com/${Uri.encodeComponent(paystackPublicKey)}?'
        'email=${Uri.encodeComponent(email)}&'
        'amount=$amountInKobo&'
        'currency=NGN';
    
    // Launch URL (Paystack will handle callback via URL scheme)
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

// ========== FCM SERVICE ==========
class FCMService {
  Future<String?> getToken() async {
    try {
      final token = await services.messaging.getToken(
        vapidKey: 'BAqzckZL6w2k3sX1v6kRso0kTytmC7SYTa8BlUQrOtiasqhhChuD-5G-K1NsarUvWoNmeqab2GgP6kOHUyCQ9XE',
      );
      return token;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveTokenToSupabase(String userId, String token) async {
    try {
      await services.supabase
          .from('provider_profiles')
          .update({
            'fcm_token': token,
            'fcm_token_updated': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
    } catch (e) {
      // Silent fail
    }
  }

  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;
  Stream<RemoteMessage> get onMessageOpenedApp => FirebaseMessaging.onMessageOpenedApp;
}

// ========== NOTIFICATION SERVICE ==========
class NotificationService {
  Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    String? clickAction,
  }) async {
    // This would call your Vercel endpoint
    try {
      await http.post(
        Uri.parse('https://gigscourt.vercel.app/api/send-notification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'title': title,
          'body': body,
          'clickAction': clickAction ?? '/',
        }),
      );
    } catch (e) {
      // Silent fail
    }
  }

  // Save notification to local Firestore
  Future<void> addNotificationToFirestore(String userId, String title, String body, {String? link}) async {
    try {
      await services.firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'link': link,
        'read': false,
        'createdAt': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
      
      // Increment unread count
      final metaRef = services.firestore.collection('user_notification_meta').doc(userId);
      await metaRef.set({'unreadCount': FieldValue.increment(1)}, SetOptions(merge: true));
    } catch (e) {
      // Silent fail
    }
  }
}

// ========== EXPORT SINGLETONS ==========
final authService = AuthService();
final firestoreService = FirestoreService();
final supabaseService = SupabaseService();
final imageKitService = ImageKitService();
final paystackService = PaystackService();
final fcmService = FCMService();
final notificationService = NotificationService();
