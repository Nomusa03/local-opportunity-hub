import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite is not used on the web.');
    }

    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'local_opportunity_hub.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE saved_opportunities (
            id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            company TEXT NOT NULL,
            type TEXT NOT NULL,
            PRIMARY KEY (id, user_id)
          )
        ''');
      },
    );
  }

  String _storageKey(String userId) {
    return 'saved_opportunities_$userId';
  }

  Future<void> saveOpportunity({
    required String id,
    required String title,
    required String company,
    required String type,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('No user is logged in.');
    }

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKey(user.uid);

      final saved = prefs.getString(key);
      final List<Map<String, dynamic>> opportunities = saved == null
          ? []
          : List<Map<String, dynamic>>.from(
              (jsonDecode(saved) as List).map(
                (item) => Map<String, dynamic>.from(item),
              ),
            );

      opportunities.removeWhere((item) => item['id'] == id);

      opportunities.add({
        'id': id,
        'user_id': user.uid,
        'title': title,
        'company': company,
        'type': type,
      });

      await prefs.setString(key, jsonEncode(opportunities));
      return;
    }

    final db = await database;

    await db.insert('saved_opportunities', {
      'id': id,
      'user_id': user.uid,
      'title': title,
      'company': company,
      'type': type,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSavedOpportunities() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return [];
    }

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageKey(user.uid));

      if (saved == null) {
        return [];
      }

      return List<Map<String, dynamic>>.from(
        (jsonDecode(saved) as List).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
    }

    final db = await database;

    return await db.query(
      'saved_opportunities',
      where: 'user_id = ?',
      whereArgs: [user.uid],
    );
  }

  Future<void> deleteSavedOpportunity(String opportunityId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = _storageKey(user.uid);
      final saved = prefs.getString(key);

      if (saved == null) {
        return;
      }

      final opportunities = List<Map<String, dynamic>>.from(
        (jsonDecode(saved) as List).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );

      opportunities.removeWhere((item) => item['id'] == opportunityId);

      await prefs.setString(key, jsonEncode(opportunities));
      return;
    }

    final db = await database;

    await db.delete(
      'saved_opportunities',
      where: 'id = ? AND user_id = ?',
      whereArgs: [opportunityId, user.uid],
    );
  }
}
