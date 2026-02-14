import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase.dart';
import '../models/profile.dart';

class AuthState {
  final User? user;
  final Profile? profile;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.profile,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null && profile != null;
  bool get isDriver => profile?.role == 'driver';

  AuthState copyWith({
    User? user,
    Profile? profile,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearProfile = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  StreamSubscription<AuthState>? _authSubscription;

  void _init() {
    final session = supabase.auth.currentSession;
    if (session != null) {
      state = state.copyWith(user: supabase.auth.currentUser, isLoading: true);
      _fetchProfile(supabase.auth.currentUser!.id);
    }

    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        state = state.copyWith(user: session.user, isLoading: true);
        _fetchProfile(session.user.id);
      } else if (event == AuthChangeEvent.signedOut) {
        state = const AuthState();
      } else if (event == AuthChangeEvent.tokenRefreshed && session != null) {
        state = state.copyWith(user: session.user);
      }
    });
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      final response =
          await supabase.from('profiles').select().eq('id', userId).single();

      final profile = Profile.fromJson(response);

      if (profile.role != 'driver') {
        state = AuthState(
          error: 'Access denied. This app is for drivers only.',
        );
        await supabase.auth.signOut();
        return;
      }

      state = AuthState(user: supabase.auth.currentUser, profile: profile);
    } catch (e) {
      state = AuthState(error: 'Failed to load profile: $e');
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        state = AuthState(error: 'Login failed. Please try again.');
        return;
      }

      state = state.copyWith(user: response.user, isLoading: true);
      await _fetchProfile(response.user!.id);
    } on AuthException catch (e) {
      state = AuthState(error: e.message);
    } catch (e) {
      state = AuthState(error: 'An unexpected error occurred: $e');
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    state = const AuthState();
  }

  Future<void> refreshProfile() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      await _fetchProfile(user.id);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
